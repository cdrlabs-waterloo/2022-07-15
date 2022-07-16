`default_nettype none
module ram(
  input  wire        clk,
  input  wire        rst_n,
  input  wire [9:0]  i_wb_mem_adr,
  input  wire        i_wb_mem_cyc,
  input  wire        i_wb_mem_we,
  input  wire [3:0]  i_wb_mem_sel,
  input  wire [31:0] i_wb_mem_dat,
  output wire [31:0] o_wb_mem_rdt,
  output reg         o_wb_mem_ack);

  // TODO instantiate the SRAM here.

endmodule
