`default_nettype none

module mux(
  input  wire         i_clk_cmo_en,
  input  wire         i_clk_dlo_en,
  input  wire         i_clk_pln_en,
  // tst
  input  wire [8:0]   i_tst_rf_addr,
  input  wire [1:0]   i_tst_rf_wdat,
  input  wire         i_tst_rf_we,
  output reg  [1:0]   o_tst_rf_rdata,
  input  wire [9:0]   i_tst_ram_adr,
  input  wire         i_tst_ram_cyc,
  input  wire         i_tst_ram_we,
  input  wire [3:0]   i_tst_ram_sel,
  input  wire [31:0]  i_tst_ram_dat,
  output reg  [31:0]  o_tst_ram_rdt,
  output reg          o_tst_ram_ack,
  // cmo
  input  wire [1:0]   i_cmo_q,
  input  wire [8:0]   i_cmo_rf_waddr,
  input  wire [1:0]   i_cmo_rf_wdata,
  input  wire         i_cmo_rf_wen,
  input  wire [8:0]   i_cmo_rf_raddr,
  output reg  [1:0]   o_cmo_rf_rdata,
  input  wire [9:0]   i_cmo_wb_mem_adr,
  input  wire         i_cmo_wb_mem_cyc,
  input  wire         i_cmo_wb_mem_we,
  input  wire [3:0]   i_cmo_wb_mem_sel,
  input  wire [31:0]  i_cmo_wb_mem_dat,
  output reg  [31:0]  o_cmo_wb_mem_rdt,
  output reg          o_cmo_wb_mem_ack,
  // dlo
  input  wire [1:0]   i_dlo_q,
  input  wire [8:0]   i_dlo_rf_waddr,
  input  wire [1:0]   i_dlo_rf_wdata,
  input  wire         i_dlo_rf_wen,
  input  wire [8:0]   i_dlo_rf_raddr,
  output reg  [1:0]   o_dlo_rf_rdata,
  input  wire [9:0]   i_dlo_wb_mem_adr,
  input  wire         i_dlo_wb_mem_cyc,
  input  wire         i_dlo_wb_mem_we,
  input  wire [3:0]   i_dlo_wb_mem_sel,
  input  wire [31:0]  i_dlo_wb_mem_dat,
  output reg  [31:0]  o_dlo_wb_mem_rdt,
  output reg          o_dlo_wb_mem_ack,
  // pln
  input  wire [1:0]   i_pln_q,
  input  wire [8:0]   i_pln_rf_waddr,
  input  wire [1:0]   i_pln_rf_wdata,
  input  wire         i_pln_rf_wen,
  input  wire [8:0]   i_pln_rf_raddr,
  output reg  [1:0]   o_pln_rf_rdata,
  input  wire [9:0]   i_pln_wb_mem_adr,
  input  wire         i_pln_wb_mem_cyc,
  input  wire         i_pln_wb_mem_we,
  input  wire [3:0]   i_pln_wb_mem_sel,
  input  wire [31:0]  i_pln_wb_mem_dat,
  output reg  [31:0]  o_pln_wb_mem_rdt,
  output reg          o_pln_wb_mem_ack,
  // q
  output reg [1:0]    o_q,
  // ram
  output reg  [9:0]   o_wb_mem_adr,
  output reg          o_wb_mem_cyc,
  output reg          o_wb_mem_we,
  output reg  [3:0]   o_wb_mem_sel,
  output reg  [31:0]  o_wb_mem_dat,
  input  wire [31:0]  i_wb_mem_rdt,
  input  wire         i_wb_mem_ack,
  // rf
  output reg  [8:0]   o_rf_waddr,
  output reg  [1:0]   o_rf_wdata,
  output reg          o_rf_wen,
  output reg  [8:0]   o_rf_raddr,
  input  wire [1:0]   i_rf_rdata);


  always @* begin
    // cmo default
    o_cmo_rf_rdata   = 2'b0;
    o_cmo_wb_mem_rdt = 32'b0;
    o_cmo_wb_mem_ack = 1'b0;
    // dlo default
    o_dlo_rf_rdata   = 2'b0;
    o_dlo_wb_mem_rdt = 32'b0;
    o_dlo_wb_mem_ack = 1'b0;
    // pln default
    o_pln_rf_rdata   = 2'b0;
    o_pln_wb_mem_rdt = 32'b0;
    o_pln_wb_mem_ack = 1'b0;
    // tst default
    o_tst_rf_rdata   = 2'b0;
    o_tst_ram_rdt    = 32'b0;
    o_tst_ram_ack    = 1'b0;

    if (i_clk_cmo_en) begin
      // q
      o_q              = i_cmo_q;
      // rf              
      o_rf_waddr       = i_cmo_rf_waddr;
      o_rf_wdata       = i_cmo_rf_wdata;
      o_rf_wen         = i_cmo_rf_wen;
      o_rf_raddr       = i_cmo_rf_raddr;
      o_cmo_rf_rdata   = i_rf_rdata;
      // ram            
      o_wb_mem_adr     = i_cmo_wb_mem_adr;
      o_wb_mem_cyc     = i_cmo_wb_mem_cyc;
      o_wb_mem_we      = i_cmo_wb_mem_we;
      o_wb_mem_sel     = i_cmo_wb_mem_sel;
      o_wb_mem_dat     = i_cmo_wb_mem_dat;
      o_cmo_wb_mem_rdt = i_wb_mem_rdt;
      o_cmo_wb_mem_ack = i_wb_mem_ack;
    end else if (i_clk_dlo_en) begin
      // q
      o_q              = i_dlo_q;
      // rf              
      o_rf_waddr       = i_dlo_rf_waddr;
      o_rf_wdata       = i_dlo_rf_wdata;
      o_rf_wen         = i_dlo_rf_wen;
      o_rf_raddr       = i_dlo_rf_raddr;
      o_dlo_rf_rdata   = i_rf_rdata;
      // ram            
      o_wb_mem_adr     = i_dlo_wb_mem_adr;
      o_wb_mem_cyc     = i_dlo_wb_mem_cyc;
      o_wb_mem_we      = i_dlo_wb_mem_we;
      o_wb_mem_sel     = i_dlo_wb_mem_sel;
      o_wb_mem_dat     = i_dlo_wb_mem_dat;
      o_dlo_wb_mem_rdt = i_wb_mem_rdt;
      o_dlo_wb_mem_ack = i_wb_mem_ack;
    end else if (i_clk_pln_en) begin
      // q
      o_q              = i_pln_q;
      // rf              
      o_rf_waddr       = i_pln_rf_waddr;
      o_rf_wdata       = i_pln_rf_wdata;
      o_rf_wen         = i_pln_rf_wen;
      o_rf_raddr       = i_pln_rf_raddr;
      o_pln_rf_rdata   = i_rf_rdata;
      // ram            
      o_wb_mem_adr     = i_pln_wb_mem_adr;
      o_wb_mem_cyc     = i_pln_wb_mem_cyc;
      o_wb_mem_we      = i_pln_wb_mem_we;
      o_wb_mem_sel     = i_pln_wb_mem_sel;
      o_wb_mem_dat     = i_pln_wb_mem_dat;
      o_pln_wb_mem_rdt = i_wb_mem_rdt;
      o_pln_wb_mem_ack = i_wb_mem_ack;
    end else begin
      // q
      o_q             = 2'b0;
      // rf             
      o_rf_waddr      = i_tst_rf_addr;
      o_rf_wdata      = i_tst_rf_wdat;
      o_rf_wen        = i_tst_rf_we;
      o_rf_raddr      = i_tst_rf_addr;
      o_tst_rf_rdata  = i_rf_rdata;
      // ram            
      o_wb_mem_adr     = i_tst_ram_adr;
      o_wb_mem_cyc     = i_tst_ram_cyc;
      o_wb_mem_we      = i_tst_ram_we;
      o_wb_mem_sel     = i_tst_ram_sel;
      o_wb_mem_dat     = i_tst_ram_dat;
      o_tst_ram_rdt    = i_wb_mem_rdt;
      o_tst_ram_ack    = i_wb_mem_ack;
    end
  end

endmodule

