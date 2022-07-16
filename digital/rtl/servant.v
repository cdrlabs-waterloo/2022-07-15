`default_nettype none

/* Arbitrates between dbus and ibus accesses.
 * Relies on the fact that not both masters are active at the same time
 */
module servant_arbiter
  (
   input wire [31:0]  i_wb_cpu_dbus_adr,
   input wire [31:0]  i_wb_cpu_dbus_dat,
   input wire [3:0]   i_wb_cpu_dbus_sel,
   input wire         i_wb_cpu_dbus_we,
   input wire         i_wb_cpu_dbus_cyc,
   output wire [31:0] o_wb_cpu_dbus_rdt,
   output wire        o_wb_cpu_dbus_ack,

   input wire [31:0]  i_wb_cpu_ibus_adr,
   input wire         i_wb_cpu_ibus_cyc,
   output wire [31:0] o_wb_cpu_ibus_rdt,
   output wire        o_wb_cpu_ibus_ack,

   output wire [31:0] o_wb_cpu_adr,
   output wire [31:0] o_wb_cpu_dat,
   output wire [3:0]  o_wb_cpu_sel,
   output wire        o_wb_cpu_we,
   output wire        o_wb_cpu_cyc,
   input wire [31:0]  i_wb_cpu_rdt,
   input wire         i_wb_cpu_ack);

   assign o_wb_cpu_dbus_rdt = i_wb_cpu_rdt;
   assign o_wb_cpu_dbus_ack = i_wb_cpu_ack & !i_wb_cpu_ibus_cyc;

   assign o_wb_cpu_ibus_rdt = i_wb_cpu_rdt;
   assign o_wb_cpu_ibus_ack = i_wb_cpu_ack & i_wb_cpu_ibus_cyc;

   assign o_wb_cpu_adr = i_wb_cpu_ibus_cyc ? i_wb_cpu_ibus_adr : i_wb_cpu_dbus_adr;
   assign o_wb_cpu_dat = i_wb_cpu_dbus_dat;
   assign o_wb_cpu_sel = i_wb_cpu_dbus_sel;
   assign o_wb_cpu_we  = i_wb_cpu_dbus_we & !i_wb_cpu_ibus_cyc;
   assign o_wb_cpu_cyc = i_wb_cpu_ibus_cyc | i_wb_cpu_dbus_cyc;

endmodule


module servant_gpio
  (input wire clk,
   input wire rst_n,
   input wire [1:0] i_wb_dat,
   input wire i_wb_we,
   input wire i_wb_cyc,
   output wire [1:0] o_wb_rdt,
   output reg [1:0] o_gpio);

   assign o_wb_rdt = o_gpio;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n)
        o_gpio <= 2'b0;
      else if (i_wb_cyc & i_wb_we)
        o_gpio <= i_wb_dat;
   end
endmodule


/*
 Bits 31:30 of address:
 mem            = 00
 gpio           = 01
 test compliant = 10
 */
module servant_mux
  (
   input wire         clk,
   input wire         rst_n,
   input wire [31:0]  i_wb_cpu_adr,
   input wire [31:0]  i_wb_cpu_dat,
   input wire [3:0]   i_wb_cpu_sel,
   input wire         i_wb_cpu_we,
   input wire         i_wb_cpu_cyc,
   output wire [31:0] o_wb_cpu_rdt,
   output reg         o_wb_cpu_ack,

   output wire [31:0] o_wb_mem_adr,
   output wire [31:0] o_wb_mem_dat,
   output wire [3:0]  o_wb_mem_sel,
   output wire        o_wb_mem_we,
   output wire        o_wb_mem_cyc,
   input wire [31:0]  i_wb_mem_rdt,

   output wire [1:0]  o_wb_gpio_dat,
   output wire        o_wb_gpio_we,
   output wire        o_wb_gpio_cyc,
   input wire  [1:0]  i_wb_gpio_rdt);

   wire [1:0]     s = i_wb_cpu_adr[31:30];

   assign o_wb_cpu_rdt = s[0] ? {30'd0,i_wb_gpio_rdt} : i_wb_mem_rdt;
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n)
        o_wb_cpu_ack <= 1'b0;
      else begin
        o_wb_cpu_ack <= 1'b0;
        if (i_wb_cpu_cyc & !o_wb_cpu_ack)
          o_wb_cpu_ack <= 1'b1;
      end
   end

   assign o_wb_mem_adr = i_wb_cpu_adr;
   assign o_wb_mem_dat = i_wb_cpu_dat;
   assign o_wb_mem_sel = i_wb_cpu_sel;
   assign o_wb_mem_we  = i_wb_cpu_we;
   assign o_wb_mem_cyc = i_wb_cpu_cyc & (s == 2'b00);

   assign o_wb_gpio_dat = i_wb_cpu_dat[1:0];
   assign o_wb_gpio_we  = i_wb_cpu_we;
   assign o_wb_gpio_cyc = i_wb_cpu_cyc & (s == 2'b01);

endmodule


module servant
(
 input  wire        clk,
 input  wire        rst_n,
 output wire [1:0]  o_q,
 output wire [8:0]  o_rf_waddr,
 output wire [1:0]  o_rf_wdata,
 output wire        o_rf_wen,
 output wire [8:0]  o_rf_raddr,
 input  wire [1:0]  i_rf_rdata,
 output wire [31:0] o_wb_mem_adr,
 output wire        o_wb_mem_cyc,
 output wire        o_wb_mem_we,
 output wire [3:0]  o_wb_mem_sel,
 output wire [31:0] o_wb_mem_dat,
 input  wire [31:0] i_wb_mem_rdt,
 input  wire        i_wb_mem_ack);


   wire [31:0]  wb_ibus_adr;
   wire         wb_ibus_cyc;
   wire [31:0]  wb_ibus_rdt;
   wire         wb_ibus_ack;

   wire [31:0]  wb_dbus_adr;
   wire [31:0]  wb_dbus_dat;
   wire [3:0]   wb_dbus_sel;
   wire         wb_dbus_we;
   wire         wb_dbus_cyc;
   wire [31:0]  wb_dbus_rdt;
   wire         wb_dbus_ack;

   wire [31:0]  wb_dmem_adr;
   wire [31:0]  wb_dmem_dat;
   wire [3:0]   wb_dmem_sel;
   wire         wb_dmem_we;
   wire         wb_dmem_cyc;
   wire [31:0]  wb_dmem_rdt;
   wire         wb_dmem_ack;

   wire [1:0]   wb_gpio_dat;
   wire         wb_gpio_we;
   wire         wb_gpio_cyc;
   wire [1:0]   wb_gpio_rdt;

   servant_arbiter arbiter
     (.i_wb_cpu_dbus_adr (wb_dmem_adr),
      .i_wb_cpu_dbus_dat (wb_dmem_dat),
      .i_wb_cpu_dbus_sel (wb_dmem_sel),
      .i_wb_cpu_dbus_we  (wb_dmem_we ),
      .i_wb_cpu_dbus_cyc (wb_dmem_cyc),
      .o_wb_cpu_dbus_rdt (wb_dmem_rdt),
      .o_wb_cpu_dbus_ack (wb_dmem_ack),

      .i_wb_cpu_ibus_adr (wb_ibus_adr),
      .i_wb_cpu_ibus_cyc (wb_ibus_cyc),
      .o_wb_cpu_ibus_rdt (wb_ibus_rdt),
      .o_wb_cpu_ibus_ack (wb_ibus_ack),

      .o_wb_cpu_adr (o_wb_mem_adr),
      .o_wb_cpu_dat (o_wb_mem_dat),
      .o_wb_cpu_sel (o_wb_mem_sel),
      .o_wb_cpu_we  (o_wb_mem_we ),
      .o_wb_cpu_cyc (o_wb_mem_cyc),
      .i_wb_cpu_rdt (i_wb_mem_rdt),
      .i_wb_cpu_ack (i_wb_mem_ack));

   servant_mux mux
     (
      .clk          (clk),
      .rst_n        (rst_n),
      .i_wb_cpu_adr (wb_dbus_adr),
      .i_wb_cpu_dat (wb_dbus_dat),
      .i_wb_cpu_sel (wb_dbus_sel),
      .i_wb_cpu_we  (wb_dbus_we),
      .i_wb_cpu_cyc (wb_dbus_cyc),
      .o_wb_cpu_rdt (wb_dbus_rdt),
      .o_wb_cpu_ack (wb_dbus_ack),

      .o_wb_mem_adr (wb_dmem_adr),
      .o_wb_mem_dat (wb_dmem_dat),
      .o_wb_mem_sel (wb_dmem_sel),
      .o_wb_mem_we  (wb_dmem_we),
      .o_wb_mem_cyc (wb_dmem_cyc),
      .i_wb_mem_rdt (wb_dmem_rdt),

      .o_wb_gpio_dat (wb_gpio_dat),
      .o_wb_gpio_we  (wb_gpio_we),
      .o_wb_gpio_cyc (wb_gpio_cyc),
      .i_wb_gpio_rdt (wb_gpio_rdt));

   servant_gpio gpio
     (.clk      (clk),
      .rst_n    (rst_n),
      .i_wb_dat (wb_gpio_dat),
      .i_wb_we  (wb_gpio_we),
      .i_wb_cyc (wb_gpio_cyc),
      .o_wb_rdt (wb_gpio_rdt),
      .o_gpio   (o_q));

   serv_rf_top
     #(.RESET_PC (32'h0000_0000),
       .WITH_CSR(0))
   cpu
     (
      .clk            (clk),
      .rst_n          (rst_n),
      .i_timer_irq    (1'b0),
`ifdef RISCV_FORMAL
      .rvfi_valid     (),
      .rvfi_order     (),
      .rvfi_insn      (),
      .rvfi_trap      (),
      .rvfi_halt      (),
      .rvfi_intr      (),
      .rvfi_mode      (),
      .rvfi_ixl       (),
      .rvfi_rs1_addr  (),
      .rvfi_rs2_addr  (),
      .rvfi_rs1_rdata (),
      .rvfi_rs2_rdata (),
      .rvfi_rd_addr   (),
      .rvfi_rd_wdata  (),
      .rvfi_pc_rdata  (),
      .rvfi_pc_wdata  (),
      .rvfi_mem_addr  (),
      .rvfi_mem_rmask (),
      .rvfi_mem_wmask (),
      .rvfi_mem_rdata (),
      .rvfi_mem_wdata (),
`endif

      .o_ibus_adr   (wb_ibus_adr),
      .o_ibus_cyc   (wb_ibus_cyc),
      .i_ibus_rdt   (wb_ibus_rdt),
      .i_ibus_ack   (wb_ibus_ack),

      .o_dbus_adr   (wb_dbus_adr),
      .o_dbus_dat   (wb_dbus_dat),
      .o_dbus_sel   (wb_dbus_sel),
      .o_dbus_we    (wb_dbus_we),
      .o_dbus_cyc   (wb_dbus_cyc),
      .i_dbus_rdt   (wb_dbus_rdt),
      .i_dbus_ack   (wb_dbus_ack),

      .o_rf_waddr   (o_rf_waddr),
      .o_rf_wdata   (o_rf_wdata),
      .o_rf_wen     (o_rf_wen),
      .o_rf_raddr   (o_rf_raddr),
      .i_rf_rdata   (i_rf_rdata));

endmodule
