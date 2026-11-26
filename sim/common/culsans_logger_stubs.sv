// No-op stand-ins for the authors' simulation-only channel loggers
// (ccu_master_logger, snoop_chan_logger, ccu_slave_logger), which live in
// class-based test files that Verilator and synthesis cannot read.
// They only print transaction logs; they drive no signals.
module ccu_master_logger #(
  parameter time   TestTime   = 8ns,
  parameter string LoggerName = "logger",
  parameter type   aw_chan_t  = logic,
  parameter type   w_chan_t   = logic,
  parameter type   b_chan_t   = logic,
  parameter type   ar_chan_t  = logic,
  parameter type   r_chan_t   = logic
) (
  input logic clk_i, input logic rst_ni, input logic end_sim_i,
  input aw_chan_t aw_chan_i, input logic aw_valid_i, input logic aw_ready_i,
  input w_chan_t  w_chan_i,  input logic w_valid_i,  input logic w_ready_i,
  input b_chan_t  b_chan_i,  input logic b_valid_i,  input logic b_ready_i,
  input ar_chan_t ar_chan_i, input logic ar_valid_i, input logic ar_ready_i,
  input r_chan_t  r_chan_i,  input logic r_valid_i,  input logic r_ready_i
);
endmodule
module ccu_slave_logger #(
  parameter time   TestTime   = 8ns,
  parameter string LoggerName = "logger",
  parameter type   aw_chan_t  = logic,
  parameter type   w_chan_t   = logic,
  parameter type   b_chan_t   = logic,
  parameter type   ar_chan_t  = logic,
  parameter type   r_chan_t   = logic
) (
  input logic clk_i, input logic rst_ni, input logic end_sim_i,
  input aw_chan_t aw_chan_i, input logic aw_valid_i, input logic aw_ready_i,
  input w_chan_t  w_chan_i,  input logic w_valid_i,  input logic w_ready_i,
  input b_chan_t  b_chan_i,  input logic b_valid_i,  input logic b_ready_i,
  input ar_chan_t ar_chan_i, input logic ar_valid_i, input logic ar_ready_i,
  input r_chan_t  r_chan_i,  input logic r_valid_i,  input logic r_ready_i
);
endmodule
module snoop_chan_logger #(
  parameter time   TestTime   = 8ns,
  parameter string LoggerName = "logger",
  parameter type   ac_chan_t  = logic,
  parameter type   cr_chan_t  = logic,
  parameter type   cd_chan_t  = logic
) (
  input logic clk_i, input logic rst_ni, input logic end_sim_i,
  input ac_chan_t ac_chan_i, input logic ac_valid_i, input logic ac_ready_i,
  input cr_chan_t cr_chan_i, input logic cr_valid_i, input logic cr_ready_i,
  input cd_chan_t cd_chan_i, input logic cd_valid_i, input logic cd_ready_i
);
endmodule
