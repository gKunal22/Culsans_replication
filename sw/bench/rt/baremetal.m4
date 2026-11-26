dnl Splash-3 PARMACS for the Culsans bare-metal runtime (sw/bench/rt/bm.c).
dnl Same semantics as Splash-3's pthread.m4.stougie: CREATE(f, n) starts f on
dnl n-1 other harts and then runs f on the calling hart; ROI markers open and
dnl close the testbench's measurement window.
divert(-1)
define(NEWPROC,) dnl
define(SPLASH3_ROI_BEGIN, `bm_roi_begin()')
define(SPLASH3_ROI_END, `bm_roi_end()')
define(BARRIER, `{ bm_barrier(&($1), ($2)); }')
define(BARDEC, `bm_barrier_t ($1);')
define(BARINIT, `{ bm_barrier_init(&($1)); }')
define(LOCKDEC, `bm_lock_t $1;')
define(LOCKINIT, `{ bm_lock_init(&($1)); }')
define(LOCK, `{ bm_lock(&($1)); }')
define(UNLOCK, `{ bm_unlock(&($1)); }')
define(ALOCKDEC, `bm_lock_t ($1)[$2];')
define(ALOCKINIT, `{ int i; for (i = 0; i < ($2); i++) bm_lock_init(&(($1)[i])); }')
define(ALOCK, `{ bm_lock(&(($1)[($2)])); }')
define(AGETL, `(($1)[$2])')
define(AULOCK, `{ bm_unlock(&(($1)[($2)])); }')
define(PAUSEDEC, `bm_sem_t $1;')
define(PAUSEINIT, `{ bm_sem_init(&($1), 0); }')
define(CLEARPAUSE, `{;}')
define(SETPAUSE, `{ bm_sem_post(&($1)); }')
define(WAITPAUSE, `{ bm_sem_wait(&($1)); }')
define(CONDVARDEC, `bm_cond_t $1;')
define(CONDVARINIT, `bm_cond_init(&($1));')
define(CONDVARWAIT, `{ bm_cond_wait(&($1), &($2)); }')
define(CONDVARSIGNAL, `{ bm_cond_signal(&($1)); }')
define(CONDVARBCAST, `{ bm_cond_signal(&($1)); }')
define(RELEASE_FENCE, `{ __atomic_thread_fence(__ATOMIC_RELEASE); }')
define(ACQUIRE_FENCE, `{ __atomic_thread_fence(__ATOMIC_ACQUIRE); }')
define(FULL_FENCE, `{ __atomic_thread_fence(__ATOMIC_SEQ_CST); }')
define(CREATE, `{ bm_create((void (*)(void))($1), ($2)); }')
define(WAIT_FOR_END, `{ bm_wait_for_end($1); }')
define(MAIN_INITENV, `{;}')
define(MAIN_END, `{ exit(0); }')
define(INCLUDES, `
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include "bm.h"
#define PAGE_SIZE 4096
#define __MAX_THREADS__ 256
')
define(MAIN_ENV, `INCLUDES')
define(EXTERN_ENV, `INCLUDES')
define(G_MALLOC, `bm_malloc($1);')
define(NU_MALLOC, `bm_malloc($1);')
define(CLOCK, `{ ($1) = bm_cycles(); }')
divert(0)
