/* Bare-metal runtime for Splash-3 on the Culsans SoC: one software thread per hart. */
#ifndef BM_H
#define BM_H
#ifndef __ASSEMBLER__
#include <stdint.h>
#include <stddef.h>

#define BM_MAX_HARTS 2

typedef struct { volatile uint32_t v; } bm_lock_t;
typedef struct { volatile uint32_t count; volatile uint32_t sense; } bm_barrier_t;
typedef struct { volatile int32_t v; } bm_sem_t;
typedef struct { volatile uint32_t gen; } bm_cond_t;

void  bm_lock(bm_lock_t *l);
void  bm_unlock(bm_lock_t *l);
void  bm_lock_init(bm_lock_t *l);
void  bm_barrier_init(bm_barrier_t *b);
void  bm_barrier(bm_barrier_t *b, unsigned n);
void  bm_sem_init(bm_sem_t *s, int v);
void  bm_sem_post(bm_sem_t *s);
void  bm_sem_wait(bm_sem_t *s);
void  bm_cond_init(bm_cond_t *c);
void  bm_cond_wait(bm_cond_t *c, bm_lock_t *l);
void  bm_cond_signal(bm_cond_t *c);

/* run f on harts 1..n-1, then on the calling hart (Splash-3 CREATE semantics) */
void  bm_create(void (*f)(void), unsigned n);
void  bm_wait_for_end(unsigned n);

void *bm_malloc(size_t n);
unsigned long bm_cycles(void);
void  bm_roi_begin(void);
void  bm_roi_end(void);
unsigned bm_hartid(void);
#endif /* __ASSEMBLER__ */
#endif
