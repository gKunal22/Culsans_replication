# Startup for the Splash-3 bare-metal runtime: every hart enters here at 0x8010_0000.
  .section .text.init
  .globl _start
_start:
  csrr  a0, mhartid
  la    t0, bm_trap_entry
  csrw  mtvec, t0
.option push
.option norelax
  la    gp, __global_pointer$
.option pop
  li    t0, 0x2000          # mstatus.FS = Initial: enable the FPU
  csrs  mstatus, t0
  csrwi fcsr, 0
  la    sp, __stack_top     # 1 MiB of stack per hart, hart 0 at the top
  slli  t1, a0, 20
  sub   sp, sp, t1
  call  bm_start            # bm_start(hartid), never returns
1:j 1b

  .align 4
bm_trap_entry:
  csrr  a0, mcause
  csrr  a1, mepc
  csrr  a2, mtval
  call  bm_trap
2:j 2b

  .section .tohost, "aw", @progbits
  .align 6
  .globl tohost
tohost:   .dword 0
  .align 6
  .globl fromhost
fromhost: .dword 0
