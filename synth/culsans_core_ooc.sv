// One Culsans core (CVA6 with the coherent WB D-cache and ACE port) exactly as instantiated in
// culsans_xilinx (gen_ariane[i].i_ariane), for out-of-context synthesis on machines that cannot
// hold the whole SoC in memory. Total SoC = synth of culsans_xilinx with cores as black boxes + 2 x this.
module culsans_core_ooc (
  input  logic                    clk_i,
  input  logic                    rst_ni,
  input  logic [63:0]             boot_addr_i,
  input  logic [63:0]             hart_id_i,
  input  logic [1:0]              irq_i,
  input  logic                    ipi_i,
  input  logic                    time_irq_i,
  input  logic                    debug_req_i,
  output ariane_ace::req_t        axi_req_o,
  input  ariane_ace::resp_t       axi_resp_i
);
  ariane #(
    .ArianeCfg     ( culsans_pkg::ArianeFpgaSocCfg ),
    .AxiAddrWidth  ( 64                    ),
    .AxiDataWidth  ( 64                    ),
    .AxiIdWidth    ( culsans_pkg::IdWidth  ),
    .axi_ar_chan_t ( ariane_ace::ar_chan_t ),
    .axi_aw_chan_t ( ariane_ace::aw_chan_t ),
    .axi_w_chan_t  ( ariane_axi::w_chan_t  ),
    .axi_req_t     ( ariane_ace::req_t     ),
    .axi_rsp_t     ( ariane_ace::resp_t    )
  ) i_ariane (
    .clk_i, .rst_ni, .boot_addr_i, .hart_id_i, .irq_i, .ipi_i, .time_irq_i, .debug_req_i,
    .axi_req_o, .axi_resp_i
  );
endmodule
