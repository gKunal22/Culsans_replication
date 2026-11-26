// Simulator-neutral testbench for the Culsans SoC (culsans_top).
// Used unchanged by Vivado XSim and by Verilator (--timing --binary).
//
// Plusargs:
//   +HEX=<file>        64-bit-word hex image (from scripts/elf2hex.py), word 0 = 0x8000_0000
//   +MAX_CYCLES=<n>    abort after n cycles (default 50,000,000)
// Prints the cycle count when the program writes tohost (exit_o[0]).
//
// Region of interest (ROI): software on hart 0 writes mscratch = 0x524F4931 ("ROI1")
// to open it and 0x524F4930 ("ROI0") to close it. While it is open the testbench
// counts, per core, committed instructions, loads, stores and issue-stall cycles
// (the same signals as CVA6's hardware counters) and prints them when it closes.
`timescale 1ns/1ps
module tb_culsans #(
  parameter int unsigned NUM_WORDS    = 2**22,  // 32 MiB main memory
  parameter int unsigned MEM_DELAY_IN  = 0,     // extra cycles on the main-memory path (A9)
  parameter int unsigned MEM_DELAY_OUT = 0,
  // 0: authors' test map (only 0x8004_0000-0x8007_FFFF coherent)
  // 1: whole DRAM cached and coherent, as on the FPGA/Linux system (used for benchmarks)
  parameter bit          ALL_COHERENT  = 1'b0
);
  localparam ariane_pkg::ariane_cfg_t CFG = ALL_COHERENT ? culsans_pkg::ArianeFpgaSocCfg
                                                         : culsans_pkg::ArianeSocCfg;
  localparam int unsigned NC = culsans_pkg::NB_CORES;
  localparam time CLK_PERIOD = 10ns;
  logic clk = 1'b0, rtc = 1'b0, rst_n = 1'b0;
  logic [31:0] exit_val;
  longint unsigned cycles = 0, max_cycles = 64'd50_000_000;
  string hex_file;

  always #(CLK_PERIOD/2) clk = ~clk;
  always #(15259ns) rtc = ~rtc;  // 32.768 kHz

  culsans_top #(
    .ArianeCfg        ( CFG  ),
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

  // ---------------- ROI performance monitor ----------------
  localparam logic [63:0] ROI_OPEN = 64'h524F4931, ROI_CLOSE = 64'h524F4930;
  logic roi_q = 1'b0;
  longint unsigned roi_start = 0, roi_cycles = 0;
  longint unsigned instr [NC], loads [NC], stores [NC], stalls [NC];
  logic [63:0] mscratch0;
  assign mscratch0 = i_culsans.gen_ariane[0].i_ariane.i_cva6.csr_regfile_i.mscratch_q;

  for (genvar c = 0; c < NC; c++) begin : gen_mon
    logic [1:0] ack;
    logic       ld0, ld1, st0, st1, stall;
    assign ack   = i_culsans.gen_ariane[c].i_ariane.i_cva6.commit_ack;
    assign ld0   = i_culsans.gen_ariane[c].i_ariane.i_cva6.commit_instr_id_commit[0].fu == ariane_pkg::LOAD;
    assign ld1   = i_culsans.gen_ariane[c].i_ariane.i_cva6.commit_instr_id_commit[1].fu == ariane_pkg::LOAD;
    assign st0   = i_culsans.gen_ariane[c].i_ariane.i_cva6.commit_instr_id_commit[0].fu == ariane_pkg::STORE;
    assign st1   = i_culsans.gen_ariane[c].i_ariane.i_cva6.commit_instr_id_commit[1].fu == ariane_pkg::STORE;
    assign stall = i_culsans.gen_ariane[c].i_ariane.i_cva6.stall_issue;
    always @(posedge clk) begin
      if (!roi_q) begin
        if (mscratch0 == ROI_OPEN) begin
          instr[c] <= 0; loads[c] <= 0; stores[c] <= 0; stalls[c] <= 0;
        end
      end else begin
        instr[c]  <= instr[c]  + ack[0] + ack[1];
        loads[c]  <= loads[c]  + (ack[0] & ld0) + (ack[1] & ld1);
        stores[c] <= stores[c] + (ack[0] & st0) + (ack[1] & st1);
        stalls[c] <= stalls[c] + stall;
      end
    end
  end

  always @(posedge clk) begin
    if (!roi_q && mscratch0 == ROI_OPEN) begin
      roi_q     <= 1'b1;
      roi_start <= cycles;
      $display("[tb] ROI open at cycle %0d", cycles);
    end else if (roi_q && mscratch0 == ROI_CLOSE) begin
      roi_q      <= 1'b0;
      roi_cycles  = cycles - roi_start;
      $display("[tb] ROI cycles=%0d", roi_cycles);
      for (int c = 0; c < NC; c++)
        $display("[tb] ROI core%0d instr=%0d loads=%0d stores=%0d stall_issue=%0d",
                 c, instr[c], loads[c], stores[c], stalls[c]);
    end
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
