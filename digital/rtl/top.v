`default_nettype none

`include "synth_defines.vh"

module hgo_top(
  input  wire HGO_TCK,
  input  wire HGO_TMS,
  input  wire HGO_TDI,
  output wire HGO_TDO,
  input  wire HGO_RSTN,
  output wire HGO_Q0,
  output wire HGO_Q1);

  localparam CMO_RANDBITS_LEN = `CMO_RANDBITS_LEN;
  localparam DLO_RANDBITS_LEN = `DLO_RANDBITS_LEN;
  localparam MAX_RANDBITS_LEN = `MAX_RANDBITS_LEN;

  /*
   * Extra random bits used in the RTL for various purposes such masking
   * RAM/RF data and ack outputs, or perturbing the clock randomizer, etc
   */
  localparam XTR_RANDBITS_LEN = 32+2+2+1;

  reg  [1:0] rst_n_sync;
  wire       rst_n;

  wire [1:0] q;

  wire jtag_tck;
  wire jtag_tms;
  wire jtag_tdi;
  wire jtag_tdo;

  wire [8:0]  tst_rf_addr;
  wire [1:0]  tst_rf_wdat;
  wire        tst_rf_we;
  wire [1:0]  tst_rf_rdata;

  wire [9:0]  tst_ram_adr;
  wire        tst_ram_cyc;
  wire        tst_ram_we;
  wire [3:0]  tst_ram_sel;
  wire [31:0] tst_ram_dat;
  wire [31:0] tst_ram_rdt;
  wire        tst_ram_ack;

  wire [31:0] key_enc_ram;
  wire [1:0]  key_enc_rf;
  wire [31:0] key_scr_ram;
  wire [8:0]  key_scr_rf;

  wire       clk_osc_en;
  wire [1:0] clk_sel_src;
  wire       clk_gbl_en;
  wire       clk_mem_en;
  wire [2:0] clk_sys_div;
  wire       clk_rng_en;
  wire       clk_smp_en;
  wire [2:0] clk_smp_div;
  wire       clk_cmo_en;
  wire       clk_dlo_en;
  wire       clk_pln_en;
  wire       clk_pch_rfs;
  wire [1:0] clk_rnd_sel;
  wire       clk_rnd_ptb_en;
  wire [7:0] clk_rnd_ptb_gamma;

  wire       clk_flk_bit;

  wire                 clk_mem;
  wire                 clk_rng;
  wire                 clk_smp;
  wire                 clk_cmo;
  wire                 clk_dlo;
  wire                 clk_pch;
  wire                 clk_pln;
  wire                 clk_initdone;

  wire        rng_psd_en;
  wire        rng_osc_en;
  wire        rng_osc_jit_en;
  wire [2:0]  rng_osc_jit_div;
  wire        rng_ptb_en;
  wire        rng_use_seed;
  wire [79:0] rng_seed;
  wire        rng_osc_jit;
  wire [79:0] rng_state;
  wire        rng_initdone;

  wire        sta_q_src;

  wire [MAX_RANDBITS_LEN-1:0] msk_randbits;
  wire [XTR_RANDBITS_LEN-1:0] xtr_randbits;

  tst U_TST(
    .tck                 ( jtag_tck          ) ,
    .tms                 ( jtag_tms          ) ,
    .tdi                 ( jtag_tdi          ) ,
    .tdo                 ( jtag_tdo          ) ,
    .rst_n               ( rst_n             ) ,
    .i_clk_mem           ( clk_mem           ) ,
    // RF_OP
    .o_tst_rf_addr       ( tst_rf_addr       ) ,
    .o_tst_rf_wdat       ( tst_rf_wdat       ) ,
    .o_tst_rf_we         ( tst_rf_we         ) ,
    .i_tst_rf_rdata      ( tst_rf_rdata      ) ,
    // RAM_OP
    .o_tst_ram_adr       ( tst_ram_adr       ) ,
    .o_tst_ram_cyc       ( tst_ram_cyc       ) ,
    .o_tst_ram_we        ( tst_ram_we        ) ,
    .o_tst_ram_sel       ( tst_ram_sel       ) ,
    .o_tst_ram_dat       ( tst_ram_dat       ) ,
    .i_tst_ram_rdt       ( tst_ram_rdt       ) ,
    .i_tst_ram_ack       ( tst_ram_ack       ) ,
    // KEY_OP
    .o_key_enc_ram       ( key_enc_ram       ) ,
    .o_key_enc_rf        ( key_enc_rf        ) ,
    .o_key_scr_ram       ( key_scr_ram       ) ,
    .o_key_scr_rf        ( key_scr_rf        ) ,
    // CLK_OP
    .o_clk_osc_en        ( clk_osc_en        ) ,
    .o_clk_sel_src       ( clk_sel_src       ) ,
    .o_clk_gbl_en        ( clk_gbl_en        ) ,
    .o_clk_mem_en        ( clk_mem_en        ) ,
    .o_clk_rng_en        ( clk_rng_en        ) ,
    .o_clk_smp_en        ( clk_smp_en        ) ,
    .o_clk_cmo_en        ( clk_cmo_en        ) ,
    .o_clk_dlo_en        ( clk_dlo_en        ) ,
    .o_clk_pln_en        ( clk_pln_en        ) ,
    .o_clk_sys_div       ( clk_sys_div       ) ,
    .o_clk_smp_div       ( clk_smp_div       ) ,
    .o_clk_pch_rfs       ( clk_pch_rfs       ) ,
    .o_clk_rnd_sel       ( clk_rnd_sel       ) ,
    .o_clk_rnd_ptb_en    ( clk_rnd_ptb_en    ) ,
    .o_clk_rnd_ptb_gamma ( clk_rnd_ptb_gamma ) ,
    // FLK_OP
    .o_clk_flk_bit       ( clk_flk_bit       ) ,
    // RNG_OP
    .o_rng_psd_en        ( rng_psd_en        ) ,
    .o_rng_osc_en        ( rng_osc_en        ) ,
    .o_rng_osc_jit_en    ( rng_osc_jit_en    ) ,
    .o_rng_osc_jit_div   ( rng_osc_jit_div   ) ,
    .o_rng_ptb_en        ( rng_ptb_en        ) ,
    .o_rng_use_seed      ( rng_use_seed      ) ,
    .o_rng_seed          ( rng_seed          ) ,
    .i_rng_state         ( rng_state         ) ,
    // STA_OP
    .o_sta_q_src         ( sta_q_src         ) ,
    .i_rng_initdone      ( rng_initdone      ) ,
    .i_clk_initdone      ( clk_initdone      ) ,
    .i_q                 ( q                 ) );

  clkg U_CLKG(
    .clk_jtag            ( jtag_tck          ) ,
    .rst_n               ( rst_n             ) ,
    .i_clk_osc_en        ( clk_osc_en        ) ,
    .i_clk_flk_bit       ( clk_flk_bit       ) ,
    .i_clk_sel_src       ( clk_sel_src       ) ,
    .i_clk_gbl_en        ( clk_gbl_en        ) ,
    .i_clk_mem_en        ( clk_mem_en        ) ,
    .i_clk_rng_en        ( clk_rng_en        ) ,
    .i_clk_smp_en        ( clk_smp_en        ) ,
    .i_clk_cmo_en        ( clk_cmo_en        ) ,
    .i_clk_dlo_en        ( clk_dlo_en        ) ,
    .i_clk_pln_en        ( clk_pln_en        ) ,
    .i_clk_sys_div       ( clk_sys_div       ) ,
    .i_clk_smp_div       ( clk_smp_div       ) ,
    .i_clk_pch_rfs       ( clk_pch_rfs       ) ,
    .i_clk_rnd_sel       ( clk_rnd_sel       ) ,
    .i_clk_rnd_ptb_en    ( clk_rnd_ptb_en    ) ,
    .i_clk_rnd_ptb_gamma ( clk_rnd_ptb_gamma ) ,
    .i_rng_psd_en        ( rng_psd_en        ) ,
    .i_rng_initdone      ( rng_initdone      ) ,
    .i_rng_ptb           ( xtr_randbits[0]   ) ,
    .o_clk_mem           ( clk_mem           ) ,
    .o_clk_rng           ( clk_rng           ) ,
    .o_clk_smp           ( clk_smp           ) ,
    .o_clk_cmo           ( clk_cmo           ) ,
    .o_clk_dlo           ( clk_dlo           ) ,
    .o_clk_pch           ( clk_pch           ) ,
    .o_clk_pln           ( clk_pln           ) ,
    .o_clk_initdone      ( clk_initdone      ) );

  rng U_RNG(
    .clk_rng           ( clk_rng         ) ,
    .clk_smp           ( clk_smp         ) ,
    .rst_n             ( rst_n           ) ,
    .i_rng_psd_en      ( rng_psd_en      ) ,
    .i_rng_osc_en      ( rng_osc_en      ) ,
    .i_rng_osc_jit_en  ( rng_osc_jit_en  ) ,
    .i_rng_osc_jit_div ( rng_osc_jit_div ) ,
    .i_rng_ptb_en      ( rng_ptb_en      ) ,
    .i_rng_use_seed    ( rng_use_seed    ) ,
    .i_rng_seed        ( rng_seed        ) ,
    .o_rng_osc_jit     ( rng_osc_jit     ) ,
    .o_rng_state       ( rng_state       ) ,
    .o_rng_initdone    ( rng_initdone    ) );
  
`ifdef RTL
  assign msk_randbits = rng_state;
  assign xtr_randbits = rng_state[XTR_RANDBITS_LEN-1:0];
`else
  // the verilog for this module mus be generated with the `cmbtr.py`
  // script after synthesizing the servants modules
  cmbtr U_CMBTR(
    .i_cmbtr_state    ( rng_state                    ),
    .o_cmbtr_randbits ( {xtr_randbits, msk_randbits} ) );
`endif

  servant_top #(.CMO_RANDBITS_LEN ( CMO_RANDBITS_LEN ),
                .DLO_RANDBITS_LEN ( DLO_RANDBITS_LEN ),
                .MAX_RANDBITS_LEN ( MAX_RANDBITS_LEN ),
                .XTR_RANDBITS_LEN ( XTR_RANDBITS_LEN ) ) U_SERVANT_TOP (
    .clk_mem        ( clk_mem        ) ,
    .clk_cmo        ( clk_cmo        ) ,
    .clk_dlo        ( clk_dlo        ) ,
    .clk_pch        ( clk_pch        ) ,
    .clk_pln        ( clk_pln        ) ,
    .rst_n          ( rst_n          ) ,
    .i_clk_cmo_en   ( clk_cmo_en     ) ,
    .i_clk_dlo_en   ( clk_dlo_en     ) ,
    .i_clk_pln_en   ( clk_pln_en     ) ,
`ifdef DISABLE_RANDOM_MASKING
    .i_msk_randbits ( { MAX_RANDBITS_LEN {1'b0}} ) ,
    .i_xtr_randbits ( { XTR_RANDBITS_LEN {1'b0}} ) ,
`else
    .i_msk_randbits ( msk_randbits   ) ,
    .i_xtr_randbits ( xtr_randbits   ) ,
`endif
    .i_key_enc_ram  ( key_enc_ram    ) ,
    .i_key_enc_rf   ( key_enc_rf     ) ,
    .i_key_scr_ram  ( key_scr_ram    ) ,
    .i_key_scr_rf   ( key_scr_rf     ) ,
    .i_tst_rf_addr  ( tst_rf_addr    ) ,
    .i_tst_rf_wdat  ( tst_rf_wdat    ) ,
    .i_tst_rf_we    ( tst_rf_we      ) ,
    .o_tst_rf_rdata ( tst_rf_rdata   ) ,
    .i_tst_ram_adr  ( tst_ram_adr    ) ,
    .i_tst_ram_cyc  ( tst_ram_cyc    ) ,
    .i_tst_ram_we   ( tst_ram_we     ) ,
    .i_tst_ram_sel  ( tst_ram_sel    ) ,
    .i_tst_ram_dat  ( tst_ram_dat    ) ,
    .o_tst_ram_rdt  ( tst_ram_rdt    ) ,
    .o_tst_ram_ack  ( tst_ram_ack    ) ,
    .o_q            ( q              ) );
  
  assign jtag_tck = HGO_TCK;
  assign jtag_tms = HGO_TMS;
  assign jtag_tdi = HGO_TDI;
  assign HGO_TDO = jtag_tdo;
  assign rst_n = rst_n_sync[1];

  always @(posedge jtag_tck or negedge HGO_RSTN)
    if (!HGO_RSTN) rst_n_sync <= 2'b0;
    else           rst_n_sync <= {rst_n_sync[0], 1'b1};

  assign HGO_Q0 = sta_q_src ? rng_osc_jit :  q[0];
  assign HGO_Q1 = sta_q_src ? clk_smp     :  q[1];

endmodule

config cfg;
  design work.hgo_top;
  instance hgo_top.U_SERVANT_TOP.U_SERVANT_CMO use libcmo.servant;
  instance hgo_top.U_SERVANT_TOP.U_SERVANT_DLO use libdlo.servant;
  instance hgo_top.U_SERVANT_TOP.U_SERVANT_PLN use libpln.servant;
endconfig

