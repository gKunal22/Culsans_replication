/* Bare-metal runtime for Splash-3 on the 2-core Culsans SoC.
 *
 * Hart 0 runs the benchmark's main(); other harts wait for work handed out by
 * CREATE (bm_create). Synchronisation uses RISC-V atomics only, so all sharing
 * goes through the coherent caches under test. Console output goes to the
 * testbench's mock UART; exit() writes tohost and flushes the D-cache so the
 * write reaches the testbench's exit monitor.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include "bm.h"
#include "bm_files.h"

#define UART_THR ((volatile uint8_t *)0x10000000UL)
#define ROI_OPEN  0x524F4931UL
#define ROI_CLOSE 0x524F4930UL

extern volatile uint64_t tohost;
extern char __heap_start[], __heap_end[], __bss_start[], __bss_end[];
extern char __tls_base[], __tdata_end[], __tbss_end[];

/* argv baked in at build time, e.g. -DBM_ARGS='"fft -p2 -m10"' */
#ifndef BM_ARGS
#define BM_ARGS "prog"
#endif
extern int main(int argc, char **argv);

/* ------------------------------------------------------------ console */
#ifdef BM_SPIKE
/* functional check on Spike (no UART at 0x10000000 there): HTIF console, device 1 command 1 */
static bm_lock_t con_lock;
static void con_put(char c)
{
  bm_lock(&con_lock);
  tohost = (1ULL << 56) | (1ULL << 48) | (unsigned char)c;
  while (tohost) ;              /* Spike clears tohost once it has taken the character */
  bm_unlock(&con_lock);
}
#else
static void con_put(char c) { *UART_THR = (uint8_t)c; }
#endif
static int bm_putc(char c, FILE *f) { (void)f; con_put(c); return (unsigned char)c; }
static FILE bm_out = FDEV_SETUP_STREAM(bm_putc, NULL, NULL, _FDEV_SETUP_WRITE);

/* stdin is fed from an embedded file (see bm_files.h), empty if none */
static const char *stdin_data; static size_t stdin_len, stdin_pos;
static int bm_getc(FILE *f) { (void)f; return stdin_pos < stdin_len ? (unsigned char)stdin_data[stdin_pos++] : EOF; }
static FILE bm_in = FDEV_SETUP_STREAM(NULL, bm_getc, NULL, _FDEV_SETUP_READ);

FILE *const stdout = &bm_out;
FILE *const stderr = &bm_out;
FILE *const stdin  = &bm_in;

/* ------------------------------------------------------------ exit */
void _exit(int code)
{
  tohost = ((uint64_t)(code & 0x7fffffff) << 1) | 1;
  __asm__ volatile("fence.i" ::: "memory");   /* writes back the D-cache, incl. tohost */
  for (;;) __asm__ volatile("wfi");
}

void bm_trap(uintptr_t cause, uintptr_t epc, uintptr_t tval)
{
  printf("\n[bm] trap on hart %u: mcause=%lx mepc=%lx mtval=%lx\n", bm_hartid(),
         (unsigned long)cause, (unsigned long)epc, (unsigned long)tval);
  _exit(1000 + (int)(cause & 0xff));
}

/* ------------------------------------------------------------ misc */
unsigned bm_hartid(void) { unsigned long h; __asm__ volatile("csrr %0, mhartid" : "=r"(h)); return h; }
unsigned long bm_cycles(void) { unsigned long c; __asm__ volatile("rdcycle %0" : "=r"(c)); return c; }
void bm_roi_begin(void) { __asm__ volatile("fence; csrw mscratch, %0" :: "r"(ROI_OPEN) : "memory"); }
void bm_roi_end(void)   { __asm__ volatile("fence; csrw mscratch, %0" :: "r"(ROI_CLOSE) : "memory"); }

/* ------------------------------------------------------------ locks etc. */
void bm_lock_init(bm_lock_t *l) { l->v = 0; }
void bm_lock(bm_lock_t *l)
{
  for (;;) {
    while (l->v) ;
    if (__atomic_exchange_n(&l->v, 1, __ATOMIC_ACQUIRE) == 0) return;
  }
}
void bm_unlock(bm_lock_t *l) { __atomic_store_n(&l->v, 0, __ATOMIC_RELEASE); }

void bm_barrier_init(bm_barrier_t *b) { b->count = 0; b->sense = 0; }
void bm_barrier(bm_barrier_t *b, unsigned n)
{
  uint32_t s = b->sense;
  if (__atomic_add_fetch(&b->count, 1, __ATOMIC_ACQ_REL) == n) {
    b->count = 0;
    __atomic_store_n(&b->sense, !s, __ATOMIC_RELEASE);
  } else {
    while (__atomic_load_n(&b->sense, __ATOMIC_ACQUIRE) == s) ;
  }
}

void bm_sem_init(bm_sem_t *s, int v) { s->v = v; }
void bm_sem_post(bm_sem_t *s) { __atomic_add_fetch(&s->v, 1, __ATOMIC_RELEASE); }
void bm_sem_wait(bm_sem_t *s)
{
  for (;;) {
    int32_t v = __atomic_load_n(&s->v, __ATOMIC_ACQUIRE);
    if (v > 0 && __atomic_compare_exchange_n(&s->v, &v, v - 1, 0, __ATOMIC_ACQ_REL, __ATOMIC_RELAXED)) return;
  }
}

void bm_cond_init(bm_cond_t *c) { c->gen = 0; }
void bm_cond_wait(bm_cond_t *c, bm_lock_t *l)
{
  uint32_t g = __atomic_load_n(&c->gen, __ATOMIC_ACQUIRE);
  bm_unlock(l);
  while (__atomic_load_n(&c->gen, __ATOMIC_ACQUIRE) == g) ;
  bm_lock(l);
}
void bm_cond_signal(bm_cond_t *c) { __atomic_add_fetch(&c->gen, 1, __ATOMIC_RELEASE); }

/* ------------------------------------------------------------ memory */
static bm_lock_t heap_lock;
static char *heap_ptr;

void *bm_malloc(size_t n)
{
  bm_lock(&heap_lock);
  if (!heap_ptr) heap_ptr = __heap_start;
  uintptr_t p = ((uintptr_t)heap_ptr + 15) & ~(uintptr_t)15;
  if (p + n > (uintptr_t)__heap_end) {
    bm_unlock(&heap_lock);
    printf("[bm] out of memory (%lu bytes requested)\n", (unsigned long)n);
    _exit(999);
  }
  heap_ptr = (char *)(p + n);
  bm_unlock(&heap_lock);
  return (void *)p;
}
/* Splash-3 never relies on free(); a bump allocator keeps every run deterministic */
void *malloc(size_t n) { return bm_malloc(n); }
void  free(void *p) { (void)p; }
void *calloc(size_t a, size_t b) { void *p = bm_malloc(a * b); memset(p, 0, a * b); return p; }
void *realloc(void *o, size_t n)
{
  void *p = bm_malloc(n);
  if (o) memcpy(p, o, n);   /* may over-read the old block; harmless inside the heap */
  return p;
}
void *memalign(size_t a, size_t n) { void *p = bm_malloc(n + a); return (void *)(((uintptr_t)p + a - 1) & ~(a - 1)); }
int posix_memalign(void **r, size_t a, size_t n) { *r = memalign(a, n); return 0; }

/* ------------------------------------------------------------ files (embedded) */
static struct { const bm_file_t *f; size_t pos; } fds[8];

int open(const char *path, int flags, ...)
{
  const char *base = strrchr(path, '/') ? strrchr(path, '/') + 1 : path;
  for (const bm_file_t *f = bm_files; f->name; f++)
    if (!strcmp(f->name, base))
      for (int i = 3; i < 8; i++)
        if (!fds[i].f) { fds[i].f = f; fds[i].pos = 0; return i; }
  if (flags & (O_WRONLY | O_RDWR)) return 8;   /* output file: writes are discarded */
  errno = ENOENT;
  return -1;
}
ssize_t read(int fd, void *buf, size_t n)
{
  if (fd < 3 || fd >= 8 || !fds[fd].f) { errno = EBADF; return -1; }
  size_t left = fds[fd].f->size - fds[fd].pos;
  if (n > left) n = left;
  memcpy(buf, fds[fd].f->data + fds[fd].pos, n);
  fds[fd].pos += n;
  return n;
}
ssize_t write(int fd, const void *buf, size_t n)
{
  const char *c = buf;
  if (fd == 1 || fd == 2) { for (size_t i = 0; i < n; i++) con_put(c[i]); return n; }
  return n;  /* output files are discarded */
}
off_t lseek(int fd, off_t off, int whence)
{
  if (fd < 3 || fd >= 8 || !fds[fd].f) { errno = EBADF; return -1; }
  if (whence == SEEK_SET) fds[fd].pos = off;
  else if (whence == SEEK_CUR) fds[fd].pos += off;
  else fds[fd].pos = fds[fd].f->size + off;
  return fds[fd].pos;
}
int close(int fd) { if (fd >= 3 && fd < 8) fds[fd].f = NULL; return 0; }

/* ------------------------------------------------------------ threads */
typedef struct {
  void (*volatile fn)(void);
  volatile uint32_t gen;
  volatile uint32_t done;
} __attribute__((aligned(64))) bm_slot_t;

static bm_slot_t slots[BM_MAX_HARTS];
static volatile uint32_t bm_ready __attribute__((section(".data"))) = 0;

void bm_create(void (*f)(void), unsigned n)
{
  if (n > BM_MAX_HARTS) {
    printf("[bm] %u threads requested, only %d harts\n", n, BM_MAX_HARTS);
    _exit(998);
  }
  for (unsigned h = 1; h < n; h++) {
    slots[h].done = 0;
    slots[h].fn = f;
    __atomic_add_fetch(&slots[h].gen, 1, __ATOMIC_RELEASE);
  }
  f();
}

void bm_wait_for_end(unsigned n)
{
  for (unsigned h = 1; h < n && h < BM_MAX_HARTS; h++)
    while (!__atomic_load_n(&slots[h].done, __ATOMIC_ACQUIRE)) ;
}

/* per-hart thread-local storage for picolibc (errno etc.) */
static char tls_area[BM_MAX_HARTS][512] __attribute__((aligned(64)));
static void bm_tls_init(unsigned h)
{
  size_t tdata = __tdata_end - __tls_base, total = __tbss_end - __tls_base;
  if (total > sizeof tls_area[0]) _exit(997);
  memcpy(tls_area[h], __tls_base, tdata);
  memset(tls_area[h] + tdata, 0, total - tdata);
  __asm__ volatile("mv tp, %0" :: "r"(tls_area[h]));
}

static void bm_worker(unsigned h)
{
  uint32_t seen = 0;
  for (;;) {
    while (__atomic_load_n(&slots[h].gen, __ATOMIC_ACQUIRE) == seen) ;
    seen = slots[h].gen;
    slots[h].fn();
    __atomic_store_n(&slots[h].done, 1, __ATOMIC_RELEASE);
  }
}

static int split_args(char *s, char **argv, int max)
{
  int n = 0;
  while (*s && n < max) {
    while (*s == ' ') *s++ = 0;
    if (!*s) break;
    argv[n++] = s;
    while (*s && *s != ' ') s++;
  }
  return n;
}

void bm_start(unsigned h)
{
  if (h != 0) {
    while (!__atomic_load_n(&bm_ready, __ATOMIC_ACQUIRE)) ;
    bm_tls_init(h);
    bm_worker(h);
  }
  memset(__bss_start, 0, __bss_end - __bss_start);
  bm_tls_init(0);
  if (bm_stdin) { stdin_data = (const char *)bm_stdin->data; stdin_len = bm_stdin->size; }
  /* hardware counters for software use; the testbench measures the ROI itself */
  __atomic_store_n(&bm_ready, 1, __ATOMIC_RELEASE);

  static char args[] = BM_ARGS;
  static char *argv[32];
  int argc = split_args(args, argv, 31);
  argv[argc] = 0;
  printf("[bm] start: %s\n", BM_ARGS);
  int r = main(argc, argv);
  exit(r);
}
