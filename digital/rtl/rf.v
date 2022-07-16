`default_nettype none
module rf(
  input wire        clk,
  input wire        rst_n,
  input wire  [8:0] i_rf_waddr,
  input wire  [1:0] i_rf_wdata,
  input wire        i_rf_wen,
  input wire  [8:0] i_rf_raddr,
  output wire [1:0] o_rf_rdata);

  // TODO instantiate the SRAM here.

endmodule
