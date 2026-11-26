/* Bare-metal layout for Splash-3 on the 2-core Culsans SoC (32 MiB DRAM in tb_culsans).
 * 0x8000_0000 tohost (watched by the SoC/testbench)
 * 0x8010_0000 code (boot address), data, bss
 * _end .. 0x81E0_0000 heap (G_MALLOC / malloc)
 * 0x81E0_0000 .. 0x8200_0000 stacks, 1 MiB per hart                         */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0x80000000;
  .tohost : { *(.tohost) }
  . = 0x80100000;
  .text.init : { *(.text.init) }
  .text : { *(.text .text.*) }
  .rodata : { *(.rodata .rodata.* .srodata .srodata.*) }
  . = ALIGN(64);
  .data : { *(.data .data.*) }
  .sdata : {
    __global_pointer$ = . + 0x800;
    *(.sdata .sdata.*)
  }
  . = ALIGN(64);
  .tdata : { __tls_base = .; *(.tdata .tdata.*) __tdata_end = .; }
  .tbss : { *(.tbss .tbss.*) . = ALIGN(16); __tbss_end = .; }
  __tdata_source = __tls_base;
  __tdata_size = __tdata_end - __tls_base;
  __tbss_size = __tbss_end - __tdata_end;
  __tls_size = __tbss_end - __tls_base;
  __tls_align = 64;
  /* .tbss takes no space in the image; reserve it so .bss does not overlap */
  . = __tbss_end;
  . = ALIGN(64);
  __bss_start = .;
  .sbss : { *(.sbss .sbss.* .scommon) }
  .bss : { *(.bss .bss.* COMMON) }
  . = ALIGN(64);
  __bss_end = .;
  _end = .;
  __heap_start = .;
  __heap_end = 0x81E00000;
  __stack_top = 0x82000000;
}
