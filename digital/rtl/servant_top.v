`default_nettype none

module sec(
  input  wire [1:0]  i_key_enc_rf,           // encryption key for regfile
  input  wire [31:0] i_key_enc_ram,          // encryption key for ram
  input  wire [8:0]  i_key_scr_rf,           // scrambling key for regfile
  input  wire [31:0] i_key_scr_ram,          // scrambling key for ram
`ifndef RTL
  input  wire [8:0]  i_rf_waddr_s1,          // regfile write addr              (plain)
  input  wire [8:0]  i_rf_raddr_s1,          // regfile read addr               (plain)
  input  wire [1:0]  i_rf_wdata_s1,          // regfile write data              (plain)
  input  wire [1:0]  i_rf_rdata_enc_s1,      // regfile read data               (encrypted)
  output wire [8:0]  o_rf_waddr_scr_s1,      // scrambled reg file write addr   (encrypted)
  output wire [8:0]  o_rf_raddr_scr_s1,      // scrambled reg file read addr    (encrypted)
  output wire [1:0]  o_rf_wdata_enc_s1,      // encrypted regfile write data    (encrypted)
  output wire [1:0]  o_rf_rdata_s1,          // encrypted regfile read data     (plain)
  input  wire [31:0] i_wb_mem_adr_s1,        // ram address                     (plain)
  input  wire [31:0] i_wb_mem_dat_s1,        // ram write data                  (plain)
  input  wire [31:0] i_wb_mem_rdt_enc_s1,    // ram read data                   (encrypted)
  output wire [31:0] o_wb_mem_adr_scr_s1,    // scrambled ram address           (encrypted)
  output wire [31:0] o_wb_mem_dat_enc_s1,    // encrypted ram write data        (encrypted)
  output wire [31:0] o_wb_mem_rdt_s1,        // encrypted ram read data         (plain)
`endif
  input  wire [8:0]  i_rf_waddr,             // regfile write addr              (plain)
  input  wire [8:0]  i_rf_raddr,             // regfile read addr               (plain)
  input  wire [1:0]  i_rf_wdata,             // regfile write data              (plain)
  input  wire [1:0]  i_rf_rdata_enc,         // regfile read data               (encrypted)
  output wire [8:0]  o_rf_waddr_scr,         // scrambled reg file write addr   (encrypted)
  output wire [8:0]  o_rf_raddr_scr,         // scrambled reg file read addr    (encrypted)
  output wire [1:0]  o_rf_wdata_enc,         // encrypted regfile write data    (encrypted)
  output wire [1:0]  o_rf_rdata,             // encrypted regfile read data     (plain)
  input  wire [31:0] i_wb_mem_adr,           // ram address                     (plain)
  input  wire [31:0] i_wb_mem_dat,           // ram write data                  (plain)
  input  wire [31:0] i_wb_mem_rdt_enc,       // ram read data                   (encrypted)
  output wire [31:0] o_wb_mem_adr_scr,       // scrambled ram address           (encrypted)
  output wire [31:0] o_wb_mem_dat_enc,       // encrypted ram write data        (encrypted)
  output wire [31:0] o_wb_mem_rdt);          // encrypted ram read data         (plain)

  /*
   * The content encryption of the register file cannot be made address
   * dependent because there are two address ports in the memory!
   */

  assign o_rf_waddr_scr      = i_rf_waddr       ^ i_key_scr_rf;
  assign o_rf_raddr_scr      = i_rf_raddr       ^ i_key_scr_rf;
  assign o_rf_wdata_enc      = i_rf_wdata       ^ i_key_enc_rf;
  assign o_rf_rdata          = i_rf_rdata_enc   ^ i_key_enc_rf;

  assign o_wb_mem_adr_scr    = i_wb_mem_adr     ^ i_key_scr_ram;
  assign o_wb_mem_dat_enc    = i_wb_mem_dat     ^ i_key_enc_ram ^ o_wb_mem_adr_scr;
  assign o_wb_mem_rdt        = i_wb_mem_rdt_enc ^ i_key_enc_ram ^ o_wb_mem_adr_scr;

`ifndef RTL
  assign o_rf_waddr_scr_s1      = i_rf_waddr_s1;
  assign o_rf_raddr_scr_s1      = i_rf_raddr_s1;
  assign o_rf_wdata_enc_s1      = i_rf_wdata_s1;
  assign o_rf_rdata_s1          = i_rf_rdata_enc_s1;

  assign o_wb_mem_adr_scr_s1    = i_wb_mem_adr_s1;
  assign o_wb_mem_dat_enc_s1    = i_wb_mem_dat_s1     ^ o_wb_mem_adr_scr_s1;
  assign o_wb_mem_rdt_s1        = i_wb_mem_rdt_enc_s1 ^ o_wb_mem_adr_scr_s1;
`endif

endmodule

module servant_top #(parameter CMO_RANDBITS_LEN = 0,
                     parameter DLO_RANDBITS_LEN = 0,
                     parameter MAX_RANDBITS_LEN = 0,
                     parameter XTR_RANDBITS_LEN = 0) (
  input  wire                        clk_mem,
  input  wire                        clk_cmo,
  input  wire                        clk_dlo,
  input  wire                        clk_pch,
  input  wire                        clk_pln,
  input  wire                        rst_n,
  input  wire                        i_clk_cmo_en,
  input  wire                        i_clk_dlo_en,
  input  wire                        i_clk_pln_en,
  input  wire [MAX_RANDBITS_LEN-1:0] i_msk_randbits,
  input  wire [XTR_RANDBITS_LEN-1:0] i_xtr_randbits,
  input  wire [31:0]                 i_key_enc_ram,
  input  wire [1:0]                  i_key_enc_rf,
  input  wire [31:0]                 i_key_scr_ram,
  input  wire [8:0]                  i_key_scr_rf,
  input  wire [8:0]                  i_tst_rf_addr,
  input  wire [1:0]                  i_tst_rf_wdat,
  input  wire                        i_tst_rf_we,
  output wire [1:0]                  o_tst_rf_rdata,
  input  wire [9:0]                  i_tst_ram_adr,
  input  wire                        i_tst_ram_cyc,
  input  wire                        i_tst_ram_we,
  input  wire [3:0]                  i_tst_ram_sel,
  input  wire [31:0]                 i_tst_ram_dat,
  output wire [31:0]                 o_tst_ram_rdt,
  output wire                        o_tst_ram_ack,
  output wire [1:0]                  o_q);

  wire [1:0]  cmo_q;
  wire [1:0]  dlo_q;
  wire [1:0]  pln_q;

`ifndef RTL
  wire [1:0]  cmo_q_s1;
  wire [1:0]  dlo_q_s1;
`endif

  wire [8:0]  cmo_rf_waddr_scr;
  wire [8:0]  cmo_rf_raddr_scr;
  wire [31:0] cmo_wb_mem_adr_scr;

  wire [1:0]  cmo_rf_wdata_enc;
  wire [1:0]  cmo_rf_rdata_enc;
  wire [31:0] cmo_wb_mem_dat_enc;
  wire [31:0] cmo_wb_mem_rdt_enc;

  wire [8:0]  dlo_rf_waddr_scr;
  wire [8:0]  dlo_rf_raddr_scr;
  wire [31:0] dlo_wb_mem_adr_scr;

  wire [1:0]  dlo_rf_wdata_enc;
  wire [1:0]  dlo_rf_rdata_enc;
  wire [31:0] dlo_wb_mem_dat_enc;
  wire [31:0] dlo_wb_mem_rdt_enc;

`ifndef RTL
  wire [8:0]  cmo_rf_waddr_scr_s1;
  wire [8:0]  cmo_rf_raddr_scr_s1;
  wire [31:0] cmo_wb_mem_adr_scr_s1;

  wire [1:0]  cmo_rf_wdata_enc_s1;
  wire [1:0]  cmo_rf_rdata_enc_s1;
  wire [31:0] cmo_wb_mem_dat_enc_s1;
  wire [31:0] cmo_wb_mem_rdt_enc_s1;

  wire [8:0]  dlo_rf_waddr_scr_s1;
  wire [8:0]  dlo_rf_raddr_scr_s1;
  wire [31:0] dlo_wb_mem_adr_scr_s1;

  wire [1:0]  dlo_rf_wdata_enc_s1;
  wire [1:0]  dlo_rf_rdata_enc_s1;
  wire [31:0] dlo_wb_mem_dat_enc_s1;
  wire [31:0] dlo_wb_mem_rdt_enc_s1;
`endif

  wire [31:0] cmo_wb_mem_adr;
  wire        cmo_wb_mem_cyc;
  wire        cmo_wb_mem_we;
  wire [3:0]  cmo_wb_mem_sel;
  wire [31:0] cmo_wb_mem_dat;
  wire [31:0] cmo_wb_mem_rdt;
  wire        cmo_wb_mem_ack;

  wire [31:0] dlo_wb_mem_adr;
  wire        dlo_wb_mem_cyc;
  wire        dlo_wb_mem_we;
  wire [3:0]  dlo_wb_mem_sel;
  wire [31:0] dlo_wb_mem_dat;
  wire [31:0] dlo_wb_mem_rdt;
  wire        dlo_wb_mem_ack;

`ifndef RTL
  wire [31:0] cmo_wb_mem_adr_s1;
  wire        cmo_wb_mem_cyc_s1;
  wire        cmo_wb_mem_we_s1;
  wire [3:0]  cmo_wb_mem_sel_s1;
  wire [31:0] cmo_wb_mem_dat_s1;
  wire [31:0] cmo_wb_mem_rdt_s1;
  wire        cmo_wb_mem_ack_s1;

  wire [31:0] dlo_wb_mem_adr_s1;
  wire        dlo_wb_mem_cyc_s1;
  wire        dlo_wb_mem_we_s1;
  wire [3:0]  dlo_wb_mem_sel_s1;
  wire [31:0] dlo_wb_mem_dat_s1;
  wire [31:0] dlo_wb_mem_rdt_s1;
  wire        dlo_wb_mem_ack_s1;
`endif

  wire [31:0] pln_wb_mem_adr;
  wire        pln_wb_mem_cyc;
  wire        pln_wb_mem_we;
  wire [3:0]  pln_wb_mem_sel;
  wire [31:0] pln_wb_mem_dat;
  wire [31:0] pln_wb_mem_rdt;
  wire        pln_wb_mem_ack;

  wire [8:0] cmo_rf_waddr;
  wire [1:0] cmo_rf_wdata;
  wire       cmo_rf_wen;
  wire [8:0] cmo_rf_raddr;
  wire [1:0] cmo_rf_rdata;

  wire [8:0] dlo_rf_waddr;
  wire [1:0] dlo_rf_wdata;
  wire       dlo_rf_wen;
  wire [8:0] dlo_rf_raddr;
  wire [1:0] dlo_rf_rdata;

`ifndef RTL
  wire [8:0] cmo_rf_waddr_s1;
  wire [1:0] cmo_rf_wdata_s1;
  wire       cmo_rf_wen_s1;
  wire [8:0] cmo_rf_raddr_s1;
  wire [1:0] cmo_rf_rdata_s1;

  wire [8:0] dlo_rf_waddr_s1;
  wire [1:0] dlo_rf_wdata_s1;
  wire       dlo_rf_wen_s1;
  wire [8:0] dlo_rf_raddr_s1;
  wire [1:0] dlo_rf_rdata_s1;
`endif

  wire [8:0] pln_rf_waddr;
  wire [1:0] pln_rf_wdata;
  wire       pln_rf_wen;
  wire [8:0] pln_rf_raddr;
  wire [1:0] pln_rf_rdata;

  wire [8:0] rf_waddr;
  wire [1:0] rf_wdata;
  wire       rf_wen;
  wire [8:0] rf_raddr;
  wire [1:0] rf_rdata;

  wire [9:0]  wb_mem_adr;
  wire        wb_mem_cyc;
  wire        wb_mem_we;
  wire [3:0]  wb_mem_sel;
  wire [31:0] wb_mem_dat;
  wire [31:0] wb_mem_rdt;
  wire        wb_mem_ack;

`ifndef RTL
  wire [1:0]  cmo_rf_rdata_enc_nsh;
  wire [31:0] cmo_wb_mem_rdt_enc_nsh;
  wire        cmo_wb_mem_ack_nsh;

  wire [1:0]  dlo_rf_rdata_enc_nsh;
  wire [31:0] dlo_wb_mem_rdt_enc_nsh;
  wire        dlo_wb_mem_ack_nsh;
`endif

  wire [CMO_RANDBITS_LEN-1:0] msk_randbits_cmo;
  wire [DLO_RANDBITS_LEN-1:0] msk_randbits_dlo;

  assign msk_randbits_cmo = i_msk_randbits[CMO_RANDBITS_LEN-1:0];
  assign msk_randbits_dlo = i_msk_randbits[DLO_RANDBITS_LEN-1:0];

  sec U_SEC_CMO(
    .i_key_enc_rf        ( i_key_enc_rf          ) ,
    .i_key_enc_ram       ( i_key_enc_ram         ) ,
    .i_key_scr_rf        ( i_key_scr_rf          ) ,
    .i_key_scr_ram       ( i_key_scr_ram         ) ,
`ifndef RTL
    .i_rf_waddr_s1       ( cmo_rf_waddr_s1       ) ,
    .i_rf_raddr_s1       ( cmo_rf_raddr_s1       ) ,
    .i_rf_wdata_s1       ( cmo_rf_wdata_s1       ) ,
    .i_rf_rdata_enc_s1   ( cmo_rf_rdata_enc_s1   ) ,
    .o_rf_waddr_scr_s1   ( cmo_rf_waddr_scr_s1   ) ,
    .o_rf_raddr_scr_s1   ( cmo_rf_raddr_scr_s1   ) ,
    .o_rf_wdata_enc_s1   ( cmo_rf_wdata_enc_s1   ) ,
    .o_rf_rdata_s1       ( cmo_rf_rdata_s1       ) ,
    .i_wb_mem_adr_s1     ( cmo_wb_mem_adr_s1     ) ,
    .i_wb_mem_dat_s1     ( cmo_wb_mem_dat_s1     ) ,
    .i_wb_mem_rdt_enc_s1 ( cmo_wb_mem_rdt_enc_s1 ) ,
    .o_wb_mem_adr_scr_s1 ( cmo_wb_mem_adr_scr_s1 ) ,
    .o_wb_mem_dat_enc_s1 ( cmo_wb_mem_dat_enc_s1 ) ,
    .o_wb_mem_rdt_s1     ( cmo_wb_mem_rdt_s1     ) ,
`endif
    .i_rf_waddr          ( cmo_rf_waddr          ) ,
    .i_rf_raddr          ( cmo_rf_raddr          ) ,
    .i_rf_wdata          ( cmo_rf_wdata          ) ,
    .i_rf_rdata_enc      ( cmo_rf_rdata_enc      ) ,
    .o_rf_waddr_scr      ( cmo_rf_waddr_scr      ) ,
    .o_rf_raddr_scr      ( cmo_rf_raddr_scr      ) ,
    .o_rf_wdata_enc      ( cmo_rf_wdata_enc      ) ,
    .o_rf_rdata          ( cmo_rf_rdata          ) ,
    .i_wb_mem_adr        ( cmo_wb_mem_adr        ) ,
    .i_wb_mem_dat        ( cmo_wb_mem_dat        ) ,
    .i_wb_mem_rdt_enc    ( cmo_wb_mem_rdt_enc    ) ,
    .o_wb_mem_adr_scr    ( cmo_wb_mem_adr_scr    ) ,
    .o_wb_mem_dat_enc    ( cmo_wb_mem_dat_enc    ) ,
    .o_wb_mem_rdt        ( cmo_wb_mem_rdt        ) );

  sec U_SEC_DLO(
    .i_key_enc_rf        ( i_key_enc_rf          ) ,
    .i_key_enc_ram       ( i_key_enc_ram         ) ,
    .i_key_scr_rf        ( i_key_scr_rf          ) ,
    .i_key_scr_ram       ( i_key_scr_ram         ) ,
`ifndef RTL
    .i_rf_waddr_s1       ( dlo_rf_waddr_s1       ) ,
    .i_rf_raddr_s1       ( dlo_rf_raddr_s1       ) ,
    .i_rf_wdata_s1       ( dlo_rf_wdata_s1       ) ,
    .i_rf_rdata_enc_s1   ( dlo_rf_rdata_enc_s1   ) ,
    .o_rf_waddr_scr_s1   ( dlo_rf_waddr_scr_s1   ) ,
    .o_rf_raddr_scr_s1   ( dlo_rf_raddr_scr_s1   ) ,
    .o_rf_wdata_enc_s1   ( dlo_rf_wdata_enc_s1   ) ,
    .o_rf_rdata_s1       ( dlo_rf_rdata_s1       ) ,
    .i_wb_mem_adr_s1     ( dlo_wb_mem_adr_s1     ) ,
    .i_wb_mem_dat_s1     ( dlo_wb_mem_dat_s1     ) ,
    .i_wb_mem_rdt_enc_s1 ( dlo_wb_mem_rdt_enc_s1 ) ,
    .o_wb_mem_adr_scr_s1 ( dlo_wb_mem_adr_scr_s1 ) ,
    .o_wb_mem_dat_enc_s1 ( dlo_wb_mem_dat_enc_s1 ) ,
    .o_wb_mem_rdt_s1     ( dlo_wb_mem_rdt_s1     ) ,
`endif
    .i_rf_waddr          ( dlo_rf_waddr          ) ,
    .i_rf_raddr          ( dlo_rf_raddr          ) ,
    .i_rf_wdata          ( dlo_rf_wdata          ) ,
    .i_rf_rdata_enc      ( dlo_rf_rdata_enc      ) ,
    .o_rf_waddr_scr      ( dlo_rf_waddr_scr      ) ,
    .o_rf_raddr_scr      ( dlo_rf_raddr_scr      ) ,
    .o_rf_wdata_enc      ( dlo_rf_wdata_enc      ) ,
    .o_rf_rdata          ( dlo_rf_rdata          ) ,
    .i_wb_mem_adr        ( dlo_wb_mem_adr        ) ,
    .i_wb_mem_dat        ( dlo_wb_mem_dat        ) ,
    .i_wb_mem_rdt_enc    ( dlo_wb_mem_rdt_enc    ) ,
    .o_wb_mem_adr_scr    ( dlo_wb_mem_adr_scr    ) ,
    .o_wb_mem_dat_enc    ( dlo_wb_mem_dat_enc    ) ,
    .o_wb_mem_rdt        ( dlo_wb_mem_rdt        ) );

`ifndef RTL
  /*
   * The data read from RF/RAM is split into shares here, but it still
   * needs to be decrypted before fed to the servants.
   */
  assign cmo_wb_mem_ack        = cmo_wb_mem_ack_nsh      ^ i_xtr_randbits[1];
  assign cmo_wb_mem_ack_s1     =                           i_xtr_randbits[1];
  assign cmo_rf_rdata_enc      = cmo_rf_rdata_enc_nsh    ^ i_xtr_randbits[3:2];
  assign cmo_rf_rdata_enc_s1   =                           i_xtr_randbits[3:2];
  assign cmo_wb_mem_rdt_enc    = cmo_wb_mem_rdt_enc_nsh  ^ i_xtr_randbits[35:4];
  assign cmo_wb_mem_rdt_enc_s1 =                           i_xtr_randbits[35:4];

  assign dlo_wb_mem_ack        = dlo_wb_mem_ack_nsh      ^ i_xtr_randbits[1];
  assign dlo_wb_mem_ack_s1     =                           i_xtr_randbits[1];
  assign dlo_rf_rdata_enc      = dlo_rf_rdata_enc_nsh    ^ i_xtr_randbits[3:2];
  assign dlo_rf_rdata_enc_s1   =                           i_xtr_randbits[3:2];
  assign dlo_wb_mem_rdt_enc    = dlo_wb_mem_rdt_enc_nsh  ^ i_xtr_randbits[35:4];
  assign dlo_wb_mem_rdt_enc_s1 =                           i_xtr_randbits[35:4];
`endif

  servant U_SERVANT_CMO(
    .clk             ( clk_cmo           ) ,
    .rst_n           ( rst_n             ) ,
`ifndef RTL
    .randbits        ( msk_randbits_cmo  ) ,
    .o_q_s1          ( cmo_q_s1          ) ,
    .o_rf_waddr_s1   ( cmo_rf_waddr_s1   ) ,
    .o_rf_wdata_s1   ( cmo_rf_wdata_s1   ) ,
    .o_rf_wen_s1     ( cmo_rf_wen_s1     ) ,
    .o_rf_raddr_s1   ( cmo_rf_raddr_s1   ) ,
    .i_rf_rdata_s1   ( cmo_rf_rdata_s1   ) ,
    .o_wb_mem_adr_s1 ( cmo_wb_mem_adr_s1 ) ,
    .o_wb_mem_cyc_s1 ( cmo_wb_mem_cyc_s1 ) ,
    .o_wb_mem_we_s1  ( cmo_wb_mem_we_s1  ) ,
    .o_wb_mem_sel_s1 ( cmo_wb_mem_sel_s1 ) ,
    .o_wb_mem_dat_s1 ( cmo_wb_mem_dat_s1 ) ,
    .i_wb_mem_rdt_s1 ( cmo_wb_mem_rdt_s1 ) ,
    .i_wb_mem_ack_s1 ( cmo_wb_mem_ack_s1 ) ,
`endif
    .o_q             ( cmo_q             ) ,
    .o_rf_waddr      ( cmo_rf_waddr      ) ,
    .o_rf_wdata      ( cmo_rf_wdata      ) ,
    .o_rf_wen        ( cmo_rf_wen        ) ,
    .o_rf_raddr      ( cmo_rf_raddr      ) ,
    .i_rf_rdata      ( cmo_rf_rdata      ) ,
    .o_wb_mem_adr    ( cmo_wb_mem_adr    ) ,
    .o_wb_mem_cyc    ( cmo_wb_mem_cyc    ) ,
    .o_wb_mem_we     ( cmo_wb_mem_we     ) ,
    .o_wb_mem_sel    ( cmo_wb_mem_sel    ) ,
    .o_wb_mem_dat    ( cmo_wb_mem_dat    ) ,
    .i_wb_mem_rdt    ( cmo_wb_mem_rdt    ) ,
    .i_wb_mem_ack    ( cmo_wb_mem_ack    ) );

  servant U_SERVANT_DLO(
    .clk                 ( clk_dlo            ) ,
    .rst_n               ( rst_n              ) ,
`ifndef RTL
    .randbits            ( msk_randbits_dlo   ) ,
    .clk_pch             ( clk_pch            ) ,
    // inverted io
    .o_q_not             (                    ) ,
    .o_rf_waddr_not      (                    ) ,
    .o_rf_wdata_not      (                    ) ,
    .o_rf_wen_not        (                    ) ,
    .o_rf_raddr_not      (                    ) ,
    .i_rf_rdata_not      ( ~dlo_rf_rdata      ) ,
    .o_wb_mem_adr_not    (                    ) ,
    .o_wb_mem_cyc_not    (                    ) ,
    .o_wb_mem_we_not     (                    ) ,
    .o_wb_mem_sel_not    (                    ) ,
    .o_wb_mem_dat_not    (                    ) ,
    .i_wb_mem_rdt_not    ( ~dlo_wb_mem_rdt    ) ,
    .i_wb_mem_ack_not    ( ~dlo_wb_mem_ack    ) ,
    // shared io
    .o_q_s1              ( dlo_q_s1           ) ,
    .o_rf_waddr_s1       ( dlo_rf_waddr_s1    ) ,
    .o_rf_wdata_s1       ( dlo_rf_wdata_s1    ) ,
    .o_rf_wen_s1         ( dlo_rf_wen_s1      ) ,
    .o_rf_raddr_s1       ( dlo_rf_raddr_s1    ) ,
    .i_rf_rdata_s1       ( dlo_rf_rdata_s1    ) ,
    .o_wb_mem_adr_s1     ( dlo_wb_mem_adr_s1  ) ,
    .o_wb_mem_cyc_s1     ( dlo_wb_mem_cyc_s1  ) ,
    .o_wb_mem_we_s1      ( dlo_wb_mem_we_s1   ) ,
    .o_wb_mem_sel_s1     ( dlo_wb_mem_sel_s1  ) ,
    .o_wb_mem_dat_s1     ( dlo_wb_mem_dat_s1  ) ,
    .i_wb_mem_rdt_s1     ( dlo_wb_mem_rdt_s1  ) ,
    .i_wb_mem_ack_s1     ( dlo_wb_mem_ack_s1  ) ,
    // shared and inverted io
    .o_q_s1_not          (                    ) ,
    .o_rf_waddr_s1_not   (                    ) ,
    .o_rf_wdata_s1_not   (                    ) ,
    .o_rf_wen_s1_not     (                    ) ,
    .o_rf_raddr_s1_not   (                    ) ,
    .i_rf_rdata_s1_not   ( ~dlo_rf_rdata_s1   ) ,
    .o_wb_mem_adr_s1_not (                    ) ,
    .o_wb_mem_cyc_s1_not (                    ) ,
    .o_wb_mem_we_s1_not  (                    ) ,
    .o_wb_mem_sel_s1_not (                    ) ,
    .o_wb_mem_dat_s1_not (                    ) ,
    .i_wb_mem_rdt_s1_not ( ~dlo_wb_mem_rdt_s1 ) ,
    .i_wb_mem_ack_s1_not ( ~dlo_wb_mem_ack_s1 ) ,
`endif
    .o_q                 ( dlo_q              ) ,
    .o_rf_waddr          ( dlo_rf_waddr       ) ,
    .o_rf_wdata          ( dlo_rf_wdata       ) ,
    .o_rf_wen            ( dlo_rf_wen         ) ,
    .o_rf_raddr          ( dlo_rf_raddr       ) ,
    .i_rf_rdata          ( dlo_rf_rdata       ) ,
    .o_wb_mem_adr        ( dlo_wb_mem_adr     ) ,
    .o_wb_mem_cyc        ( dlo_wb_mem_cyc     ) ,
    .o_wb_mem_we         ( dlo_wb_mem_we      ) ,
    .o_wb_mem_sel        ( dlo_wb_mem_sel     ) ,
    .o_wb_mem_dat        ( dlo_wb_mem_dat     ) ,
    .i_wb_mem_rdt        ( dlo_wb_mem_rdt     ) ,
    .i_wb_mem_ack        ( dlo_wb_mem_ack     ) );

  servant U_SERVANT_PLN(
    .clk          ( clk_pln          ) ,
    .rst_n        ( rst_n            ) ,
    .o_rf_waddr   ( pln_rf_waddr     ) ,
    .o_rf_wdata   ( pln_rf_wdata     ) ,
    .o_rf_wen     ( pln_rf_wen       ) ,
    .o_rf_raddr   ( pln_rf_raddr     ) ,
    .i_rf_rdata   ( pln_rf_rdata     ) ,
    .o_wb_mem_adr ( pln_wb_mem_adr   ) ,
    .o_wb_mem_cyc ( pln_wb_mem_cyc   ) ,
    .o_wb_mem_we  ( pln_wb_mem_we    ) ,
    .o_wb_mem_sel ( pln_wb_mem_sel   ) ,
    .o_wb_mem_dat ( pln_wb_mem_dat   ) ,
    .i_wb_mem_rdt ( pln_wb_mem_rdt   ) ,
    .i_wb_mem_ack ( pln_wb_mem_ack   ) ,
    .o_q          ( pln_q            ) );

  mux U_MUX(
    .i_clk_cmo_en     ( i_clk_cmo_en                                             ) ,
    .i_clk_dlo_en     ( i_clk_dlo_en                                             ) ,
    .i_clk_pln_en     ( i_clk_pln_en                                             ) ,
    // tst
    .i_tst_rf_addr    ( i_tst_rf_addr                                            ) ,
    .i_tst_rf_wdat    ( i_tst_rf_wdat                                            ) ,
    .i_tst_rf_we      ( i_tst_rf_we                                              ) ,
    .o_tst_rf_rdata   ( o_tst_rf_rdata                                           ) ,
    .i_tst_ram_adr    ( i_tst_ram_adr                                            ) ,
    .i_tst_ram_cyc    ( i_tst_ram_cyc                                            ) ,
    .i_tst_ram_we     ( i_tst_ram_we                                             ) ,
    .i_tst_ram_sel    ( i_tst_ram_sel                                            ) ,
    .i_tst_ram_dat    ( i_tst_ram_dat                                            ) ,
    .o_tst_ram_rdt    ( o_tst_ram_rdt                                            ) ,
    .o_tst_ram_ack    ( o_tst_ram_ack                                            ) ,
    // cmo
`ifdef RTL
    .i_cmo_q          ( cmo_q                                                    ) ,
    .i_cmo_rf_waddr   ( cmo_rf_waddr_scr                                         ) ,
    .i_cmo_rf_wdata   ( cmo_rf_wdata_enc                                         ) ,
    .i_cmo_rf_wen     ( cmo_rf_wen                                               ) ,
    .i_cmo_rf_raddr   ( cmo_rf_raddr_scr                                         ) ,
    .o_cmo_rf_rdata   ( cmo_rf_rdata_enc                                         ) ,
    .i_cmo_wb_mem_adr ( cmo_wb_mem_adr_scr[11:2]                                 ) ,
    .i_cmo_wb_mem_cyc ( cmo_wb_mem_cyc                                           ) ,
    .i_cmo_wb_mem_we  ( cmo_wb_mem_we                                            ) ,
    .i_cmo_wb_mem_sel ( cmo_wb_mem_sel                                           ) ,
    .i_cmo_wb_mem_dat ( cmo_wb_mem_dat_enc                                       ) ,
    .o_cmo_wb_mem_rdt ( cmo_wb_mem_rdt_enc                                       ) ,
    .o_cmo_wb_mem_ack ( cmo_wb_mem_ack                                           ) ,
`else
    .i_cmo_q          ( cmo_q_s1                    ^ cmo_q                      ) ,
    .i_cmo_rf_waddr   ( cmo_rf_waddr_scr_s1         ^ cmo_rf_waddr_scr           ) ,
    .i_cmo_rf_wdata   ( cmo_rf_wdata_enc_s1         ^ cmo_rf_wdata_enc           ) ,
    .i_cmo_rf_wen     ( cmo_rf_wen_s1               ^ cmo_rf_wen                 ) ,
    .i_cmo_rf_raddr   ( cmo_rf_raddr_scr_s1         ^ cmo_rf_raddr_scr           ) ,
    .o_cmo_rf_rdata   ( cmo_rf_rdata_enc_nsh                                     ) ,
    .i_cmo_wb_mem_adr ( cmo_wb_mem_adr_scr_s1[11:2] ^ cmo_wb_mem_adr_scr[11:2]   ) ,
    .i_cmo_wb_mem_cyc ( cmo_wb_mem_cyc_s1           ^ cmo_wb_mem_cyc             ) ,
    .i_cmo_wb_mem_we  ( cmo_wb_mem_we_s1            ^ cmo_wb_mem_we              ) ,
    .i_cmo_wb_mem_sel ( cmo_wb_mem_sel_s1           ^ cmo_wb_mem_sel             ) ,
    .i_cmo_wb_mem_dat ( cmo_wb_mem_dat_enc_s1       ^ cmo_wb_mem_dat_enc         ) ,
    .o_cmo_wb_mem_rdt ( cmo_wb_mem_rdt_enc_nsh                                   ) ,
    .o_cmo_wb_mem_ack ( cmo_wb_mem_ack_nsh                                       ) ,
`endif
    // dlo
`ifdef RTL
    .i_dlo_q          ( dlo_q                                                    ) ,
    .i_dlo_rf_waddr   ( dlo_rf_waddr_scr                                         ) ,
    .i_dlo_rf_wdata   ( dlo_rf_wdata_enc                                         ) ,
    .i_dlo_rf_wen     ( dlo_rf_wen                                               ) ,
    .i_dlo_rf_raddr   ( dlo_rf_raddr_scr                                         ) ,
    .o_dlo_rf_rdata   ( dlo_rf_rdata_enc                                         ) ,
    .i_dlo_wb_mem_adr ( dlo_wb_mem_adr_scr[11:2]                                 ) ,
    .i_dlo_wb_mem_cyc ( dlo_wb_mem_cyc                                           ) ,
    .i_dlo_wb_mem_we  ( dlo_wb_mem_we                                            ) ,
    .i_dlo_wb_mem_sel ( dlo_wb_mem_sel                                           ) ,
    .i_dlo_wb_mem_dat ( dlo_wb_mem_dat_enc                                       ) ,
    .o_dlo_wb_mem_rdt ( dlo_wb_mem_rdt_enc                                       ) ,
    .o_dlo_wb_mem_ack ( dlo_wb_mem_ack                                           ) ,
`else
    .i_dlo_q          (   dlo_q_s1                    ^ dlo_q                    ) ,
    .i_dlo_rf_waddr   (   dlo_rf_waddr_scr_s1         ^ dlo_rf_waddr_scr         ) ,
    .i_dlo_rf_wdata   (   dlo_rf_wdata_enc_s1         ^ dlo_rf_wdata_enc         ) ,
    .i_dlo_rf_wen     (   dlo_rf_wen_s1               ^ dlo_rf_wen               ) ,
    .i_dlo_rf_raddr   (   dlo_rf_raddr_scr_s1         ^ dlo_rf_raddr_scr         ) ,
    .o_dlo_rf_rdata   (   dlo_rf_rdata_enc_nsh                                   ) ,
    .i_dlo_wb_mem_adr (   dlo_wb_mem_adr_scr_s1[11:2] ^ dlo_wb_mem_adr_scr[11:2] ) ,
    .i_dlo_wb_mem_cyc (   dlo_wb_mem_cyc_s1           ^ dlo_wb_mem_cyc           ) ,
    .i_dlo_wb_mem_we  (   dlo_wb_mem_we_s1            ^ dlo_wb_mem_we            ) ,
    .i_dlo_wb_mem_sel (   dlo_wb_mem_sel_s1           ^ dlo_wb_mem_sel           ) ,
    .i_dlo_wb_mem_dat (   dlo_wb_mem_dat_enc_s1       ^ dlo_wb_mem_dat_enc       ) ,
    .o_dlo_wb_mem_rdt (   dlo_wb_mem_rdt_enc_nsh                                 ) ,
    .o_dlo_wb_mem_ack (   dlo_wb_mem_ack_nsh                                     ) ,
`endif
    // pln
    .i_pln_q          ( pln_q                                                    ) ,
    .i_pln_rf_waddr   ( pln_rf_waddr                                             ) ,
    .i_pln_rf_wdata   ( pln_rf_wdata                                             ) ,
    .i_pln_rf_wen     ( pln_rf_wen                                               ) ,
    .i_pln_rf_raddr   ( pln_rf_raddr                                             ) ,
    .o_pln_rf_rdata   ( pln_rf_rdata                                             ) ,
    .i_pln_wb_mem_adr ( pln_wb_mem_adr[11:2]                                     ) ,
    .i_pln_wb_mem_cyc ( pln_wb_mem_cyc                                           ) ,
    .i_pln_wb_mem_we  ( pln_wb_mem_we                                            ) ,
    .i_pln_wb_mem_sel ( pln_wb_mem_sel                                           ) ,
    .i_pln_wb_mem_dat ( pln_wb_mem_dat                                           ) ,
    .o_pln_wb_mem_rdt ( pln_wb_mem_rdt                                           ) ,
    .o_pln_wb_mem_ack ( pln_wb_mem_ack                                           ) ,
    // q
    .o_q              ( o_q                                                      ) ,
    // ram
    .o_wb_mem_adr     ( wb_mem_adr                                               ) ,
    .o_wb_mem_cyc     ( wb_mem_cyc                                               ) ,
    .o_wb_mem_we      ( wb_mem_we                                                ) ,
    .o_wb_mem_sel     ( wb_mem_sel                                               ) ,
    .o_wb_mem_dat     ( wb_mem_dat                                               ) ,
    .i_wb_mem_rdt     ( wb_mem_rdt                                               ) ,
    .i_wb_mem_ack     ( wb_mem_ack                                               ) ,
    // rf
    .o_rf_waddr       ( rf_waddr                                                 ) ,
    .o_rf_wdata       ( rf_wdata                                                 ) ,
    .o_rf_wen         ( rf_wen                                                   ) ,
    .o_rf_raddr       ( rf_raddr                                                 ) ,
    .i_rf_rdata       ( rf_rdata                                                 ) );


  ram U_RAM(
    .clk          ( clk_mem    ) ,
    .rst_n        ( rst_n      ) ,
    .i_wb_mem_adr ( wb_mem_adr ) ,
    .i_wb_mem_cyc ( wb_mem_cyc ) ,
    .i_wb_mem_we  ( wb_mem_we  ) ,
    .i_wb_mem_sel ( wb_mem_sel ) ,
    .i_wb_mem_dat ( wb_mem_dat ) ,
    .o_wb_mem_rdt ( wb_mem_rdt ) ,
    .o_wb_mem_ack ( wb_mem_ack ) );

  rf U_RF(
    .clk        ( clk_mem      ) ,
    .rst_n      ( rst_n        ) ,
    .i_rf_waddr ( rf_waddr     ) ,
    .i_rf_wdata ( rf_wdata     ) ,
    .i_rf_wen   ( rf_wen       ) ,
    .i_rf_raddr ( rf_raddr     ) ,
    .o_rf_rdata ( rf_rdata     ) );

endmodule

