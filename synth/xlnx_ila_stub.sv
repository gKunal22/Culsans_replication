// Empty stand-in for the authors' debug ILA (xlnx_ila). Vivado's free BASIC licence refuses
// designs with more than one ILA or ILAs with more than 5 probes (Chipscope 16-620); the ILA only
// watches signals and is not part of the evaluated design (A17). Ports as in the authors' IP settings.
module xlnx_ila (
  input wire clk,
  input wire [31:0] probe0,
  input wire [31:0] probe1,
  input wire [31:0] probe2,
  input wire [31:0] probe3,
  input wire [31:0] probe4,
  input wire [31:0] probe5,
  input wire [31:0] probe6,
  input wire [31:0] probe7,
  input wire [31:0] probe8,
  input wire [31:0] probe9,
  input wire [31:0] probe10,
  input wire [31:0] probe11,
  input wire [47:0] probe12
);
endmodule
