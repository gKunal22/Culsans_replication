// Simulator-neutral testbench for the Culsans SoC (culsans_top).
// Used unchanged by Vivado XSim and by Verilator (--timing --binary).
//
// Plusargs:
//   +HEX=<file>        64-bit-word hex image (from scripts/elf2hex.py), word 0 = 0x8000_0000
//   +MAX_CYCLES=<n>    abort after n cycles (default 50,000,000)
// Prints the cycle count when the program writes tohost (exit_o[0]).
`timescale 1ns/1ps
module tb_culsans #(
  parameter int unsigned NUM_WORDS    = 2**22,  // 32 MiB main memory
  parameter int unsigned MEM_DELAY_IN  = 0,     // extra cycles on the main-memory path (A9)
  parameter int unsigned MEM_DELAY_OUT = 0
);
  localparam time CLK_PERIOD = 10ns;
  logic clk = 1'b0, rtc = 1'b0, rst_n = 1'b0;
  logic [31:0] exit_val;
  longint unsigned cycles = 0, max_cycles = 64'd50_000_000;
  string hex_file;

  always #(CLK_PERIOD/2) clk = ~clk;
  always #(15259ns) rtc = ~rtc;  // 32.768 kHz

  culsans_top #(
    .InclSimDTM       ( 1'b0 ),
    .NUM_WORDS        ( NUM_WORDS ),
    .StallRandomInput ( 1'b0 ),
    .StallRandomOutput( 1'b0 ),
    .FixedDelayInput  ( MEM_DELAY_IN ),
    .FixedDelayOutput ( MEM_DELAY_OUT ),
    .HasLLC           ( 1'b1 ),
    .BootAddress      ( culsans_pkg::DRAMBase + 64'h10_0000 )
  ) i_culsans (
    .clk_i  ( clk      ),
    .rtc_i  ( rtc      ),
    .rst_ni ( rst_n    ),
    .exit_o ( exit_val )
  );

  always @(posedge clk) if (rst_n) cycles <= cycles + 1;

  initial begin
    if (!$value$plusargs("HEX=%s", hex_file)) hex_file = "main.hex";
    void'($value$plusargs("MAX_CYCLES=%d", max_cycles));
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    #2;
    // tc_sram re-initialises its contents during reset, so load afterwards
    $readmemh(hex_file, i_culsans.i_sram.i_tc_sram.sram);
    $display("[tb] loaded %s, running (max %0d cycles)", hex_file, max_cycles);
  end

  always @(posedge clk) begin
    if (rst_n && exit_val[0]) begin
      $display("[tb] EXIT code=%0d cycles=%0d", exit_val >> 1, cycles);
      if ((exit_val >> 1) != 0) $display("[tb] *** FAILED ***");
      else                      $display("[tb] *** SUCCESS ***");
      $finish;
    end
    if (cycles >= max_cycles) begin
      $display("[tb] TIMEOUT after %0d cycles", cycles);
      $finish;
    end
  end
endmodule
