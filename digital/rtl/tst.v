`default_nettype none

module jtag_fsm(
  input wire tck,
  input wire tms,
  input wire rst_n,
  output wire state_tlr,
  output wire state_capturedr,
  output wire state_captureir,
  output wire state_shiftdr,
  output wire state_shiftir,
  output wire state_updatedr,
  output wire state_updateir,
  output wire state_runidle
);

  `include "tst_params.vh"

  reg[3:0] state;

  always @(posedge tck or negedge rst_n) begin
    if(!rst_n) begin
      state <= TEST_LOGIC_RESET;
    end else begin
      case(state)
        TEST_LOGIC_RESET: state <= tms ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
        RUN_TEST_IDLE:    state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
        SELECT_DR:        state <= tms ? SELECT_IR        : CAPTURE_DR;
        CAPTURE_DR:       state <= tms ? EXIT1_DR         : SHIFT_DR;
        SHIFT_DR:         state <= tms ? EXIT1_DR         : SHIFT_DR;
        EXIT1_DR:         state <= tms ? UPDATE_DR        : PAUSE_DR;
        PAUSE_DR:         state <= tms ? EXIT2_DR         : PAUSE_DR;
        EXIT2_DR:         state <= tms ? UPDATE_DR        : SHIFT_DR;
        UPDATE_DR:        state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
        SELECT_IR:        state <= tms ? TEST_LOGIC_RESET : CAPTURE_IR;
        CAPTURE_IR:       state <= tms ? EXIT1_IR         : SHIFT_IR;
        SHIFT_IR:         state <= tms ? EXIT1_IR         : SHIFT_IR;
        EXIT1_IR:         state <= tms ? UPDATE_IR        : PAUSE_IR;
        PAUSE_IR:         state <= tms ? EXIT2_IR         : PAUSE_IR;
        EXIT2_IR:         state <= tms ? UPDATE_IR        : SHIFT_IR;
        UPDATE_IR:        state <= tms ? SELECT_DR        : RUN_TEST_IDLE;
      endcase
    end
  end

  assign state_tlr       = (state == TEST_LOGIC_RESET);
  assign state_capturedr = (state == CAPTURE_DR);
  assign state_captureir = (state == CAPTURE_IR);
  assign state_shiftdr   = (state == SHIFT_DR);
  assign state_shiftir   = (state == SHIFT_IR);
  assign state_updatedr  = (state == UPDATE_DR);
  assign state_updateir  = (state == UPDATE_IR);
  assign state_runidle   = (state == RUN_TEST_IDLE);

endmodule

module jtag_reg
  #( parameter DR_LEN = 0,
     parameter IR_OPCODE = 4'b0)(
    input  wire              tck,
    input  wire              tdi,
    output wire              tdo,
    input  wire              rst_n,
    input  wire              state_tlr,
    input  wire              state_capturedr,
    input  wire              state_shiftdr,
    input  wire              state_updatedr,
    input  wire [3:0]        ir_reg,
    input  wire [DR_LEN-1:0] dr_data_in,
    output reg  [DR_LEN-1:0] dr_data_out);

  reg [DR_LEN-1:0] dr_reg;

  assign tdo = dr_reg[0];

  always @(posedge tck or negedge rst_n) begin
    if(!rst_n) begin
      dr_reg      <= {DR_LEN{1'b0}};
      dr_data_out <= {DR_LEN{1'b0}};
    end else begin
      if(state_tlr) 
        dr_reg <= {DR_LEN{1'b0}};
      if(ir_reg == IR_OPCODE) begin
        if(state_capturedr)
          dr_reg <= dr_data_in;
        else if(state_shiftdr) begin
          if(DR_LEN == 1)
            dr_reg <= tdi;
          else 
            dr_reg <= {tdi, dr_reg[DR_LEN-1:1]};
        end else if(state_updatedr) begin
          dr_data_out <= dr_reg;
        end
      end
    end
  end
endmodule

module tst
  #(parameter ID_PARTVER   = 4'h0,
    parameter ID_PARTNUM   = 16'hbeef,
    parameter ID_MANF      = 11'h123)
 (
  input  wire        tck,
  input  wire        tms,
  input  wire        tdi,
  output reg         tdo,
  input  wire        rst_n,
  input  wire        i_clk_mem,
  // RF_OP
  output wire [8:0]  o_tst_rf_addr,
  output wire [1:0]  o_tst_rf_wdat,
  output wire        o_tst_rf_we,
  input  wire [1:0]  i_tst_rf_rdata,
  // RAM_OP
  output wire [9:0]  o_tst_ram_adr,
  output wire        o_tst_ram_cyc,
  output wire        o_tst_ram_we,
  output wire [3:0]  o_tst_ram_sel,
  output wire [31:0] o_tst_ram_dat,
  input  wire [31:0] i_tst_ram_rdt,
  input  wire        i_tst_ram_ack,
  // KEY_OP
  output wire [31:0] o_key_enc_ram,
  output wire [1:0]  o_key_enc_rf,
  output wire [31:0] o_key_scr_ram,
  output wire [8:0]  o_key_scr_rf,
  // CLK_OP
  output wire        o_clk_osc_en,
  output wire [1:0]  o_clk_sel_src,
  output wire        o_clk_gbl_en,
  output wire        o_clk_mem_en,
  output wire        o_clk_rng_en,
  output wire        o_clk_smp_en,
  output wire        o_clk_cmo_en,
  output wire        o_clk_dlo_en,
  output wire        o_clk_pln_en,
  output wire [2:0]  o_clk_sys_div,
  output wire [2:0]  o_clk_smp_div,
  output wire        o_clk_pch_rfs,
  output wire [1:0]  o_clk_rnd_sel,
  output wire        o_clk_rnd_ptb_en,
  output wire [7:0]  o_clk_rnd_ptb_gamma,
  // FLK_OP
  output wire        o_clk_flk_bit,
  // RNG_OP
  output wire        o_rng_psd_en,
  output wire        o_rng_osc_en,
  output wire        o_rng_osc_jit_en,
  output wire [2:0]  o_rng_osc_jit_div,
  output wire        o_rng_ptb_en,
  output wire        o_rng_use_seed,
  output wire [79:0] o_rng_seed,
  input wire  [79:0] i_rng_state,
  // STA_OP
  output wire        o_sta_q_src,
  input wire         i_rng_initdone,
  input wire         i_clk_initdone,
  input wire  [1:0]  i_q);

  `include "tst_params.vh"

  wire state_tlr, state_capturedr, state_captureir, state_shiftdr, state_shiftir,
    state_updatedr, state_updateir, state_runidle;

  // ---------------------------------------------------------------------------------
  // mandatory jtag register and logic
  //

  jtag_fsm fsm(
    .tck             ( tck             ) ,
    .tms             ( tms             ) ,
    .rst_n           ( rst_n           ) ,
    .state_tlr       ( state_tlr       ) ,
    .state_capturedr ( state_capturedr ) ,
    .state_captureir ( state_captureir ) ,
    .state_shiftdr   ( state_shiftdr   ) ,
    .state_shiftir   ( state_shiftir   ) ,
    .state_updatedr  ( state_updatedr  ) ,
    .state_updateir  ( state_updateir  ) ,
    .state_runidle   ( state_runidle   ) );

  reg[3:0] ir_reg;

  // ---------------------------------------------------------------------------------
  // IDCODE_OP
  //

  wire        idcode_tdo;
  wire [31:0] idcode_in;

  assign idcode_in = {ID_PARTVER, ID_PARTNUM, ID_MANF, 1'b1};

  jtag_reg #(
    .DR_LEN    ( IDCODE_LEN ) ,
    .IR_OPCODE ( IDCODE_OP  ) )
    idcode_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( idcode_tdo      ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( 1'b0            ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     (                 ) ,
      .dr_data_in      ( idcode_in       ) );

  // ---------------------------------------------------------------------------------
  // BYPASS_OP
  //

  wire bypass_tdo;

  jtag_reg #(
    .DR_LEN    ( BYPASS_LEN ) ,
    .IR_OPCODE ( BYPASS_OP  ))
    bypass_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( bypass_tdo      ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( 1'b0            ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     (                 ) ,
      .dr_data_in      ( 1'b0            ) );



  // ---------------------------------------------------------------------------------
  // RF_OP
  // 

  wire              rf_tdo;
  wire [RF_LEN-1:0] rf_out;
  wire [RF_LEN-1:0] rf_in;

  wire       tst_rf_go;
  wire       tst_rf_we;
  wire [8:0] tst_rf_addr;
  wire [1:0] tst_rf_wdat;

  reg              tst_rf_done;
  reg              tst_rf_we_sync;
  reg [8:0]        tst_rf_addr_sync;
  reg [1:0]        tst_rf_wdat_sync;

  reg [1:0]  tst_rf_go_sync;
  always @(posedge i_clk_mem or negedge rst_n)
    if (!rst_n) tst_rf_go_sync <= 2'b0;
    else        tst_rf_go_sync <= {tst_rf_go_sync[0], tst_rf_go};

  always @(posedge i_clk_mem or negedge rst_n)
    if (!rst_n) begin
      tst_rf_done      <= 1'b0;
      tst_rf_we_sync   <= 1'b0;
      tst_rf_addr_sync <= 9'b0;
      tst_rf_wdat_sync <= 2'b0;
    end else begin
      tst_rf_we_sync <= 1'b0;
      if (tst_rf_done) begin
        tst_rf_done      <= tst_rf_go_sync[1];
      end else if (tst_rf_go_sync[1]) begin
        tst_rf_done      <= 1'b1;
        tst_rf_we_sync   <= tst_rf_we;
        tst_rf_addr_sync <= tst_rf_addr;
        tst_rf_wdat_sync <= tst_rf_wdat;
      end
    end

  assign { tst_rf_go, tst_rf_we, tst_rf_addr, tst_rf_wdat } = rf_out;
  assign rf_in = {tst_rf_done, 1'b0, tst_rf_addr_sync, i_tst_rf_rdata};

  assign o_tst_rf_we   = tst_rf_we_sync;
  assign o_tst_rf_addr = tst_rf_addr_sync;
  assign o_tst_rf_wdat = tst_rf_wdat_sync;

  jtag_reg #(
    .DR_LEN    ( RF_LEN ) ,
    .IR_OPCODE ( RF_OP  ) )
    rf_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( rf_tdo          ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( rf_out          ) ,
      .dr_data_in      ( rf_in           ) );


  // ---------------------------------------------------------------------------------
  // RAM_OP
  // 

  wire               ram_tdo;
  wire [RAM_LEN-1:0] ram_out;
  wire [RAM_LEN-1:0] ram_in;

  wire        tst_ram_go;
  wire        tst_ram_we;
  wire [9:0]  tst_ram_adr;
  wire [31:0] tst_ram_dat;

  reg              tst_ram_done;
  reg              tst_ram_cyc_sync;
  reg              tst_ram_we_sync;
  reg [3:0]        tst_ram_sel_sync;
  reg [9:0]        tst_ram_adr_sync;
  reg [31:0]       tst_ram_dat_sync;

  reg [1:0]  tst_ram_go_sync;
  always @(posedge i_clk_mem or negedge rst_n)
    if (!rst_n) tst_ram_go_sync <= 2'b0;
    else        tst_ram_go_sync <= {tst_ram_go_sync[0], tst_ram_go};

  always @(posedge i_clk_mem or negedge rst_n)
    if (!rst_n) begin
      tst_ram_done     <= 1'b0;
      tst_ram_cyc_sync <= 1'b0;
      tst_ram_we_sync  <= 1'b0;
      tst_ram_sel_sync <= 4'b0;
      tst_ram_adr_sync <= 10'b0;
      tst_ram_dat_sync <= 32'b0;
    end else begin
      tst_ram_we_sync   <= 1'b0;
      tst_ram_cyc_sync  <= 1'b0;
      tst_ram_sel_sync  <= 4'b0;
      if (tst_ram_done) begin
        tst_ram_done      <= tst_ram_go_sync[1];
      end else if (tst_ram_go_sync[1]) begin
        tst_ram_done      <= 1'b1;
        tst_ram_cyc_sync  <= 1'b1;
        tst_ram_we_sync   <= tst_ram_we;
        tst_ram_sel_sync  <= {4 {tst_ram_we}};
        tst_ram_adr_sync  <= tst_ram_adr;
        tst_ram_dat_sync  <= tst_ram_dat;
      end
    end

  assign {tst_ram_go, tst_ram_we, tst_ram_adr, tst_ram_dat} = ram_out;
  assign ram_in = {tst_ram_done, 1'b0, tst_ram_adr_sync, i_tst_ram_rdt};

  assign o_tst_ram_cyc = tst_ram_cyc_sync;
  assign o_tst_ram_we  = tst_ram_we_sync;
  assign o_tst_ram_sel = tst_ram_sel_sync;
  assign o_tst_ram_adr = tst_ram_adr_sync;
  assign o_tst_ram_dat = tst_ram_dat_sync;

  jtag_reg #(
    .DR_LEN    ( RAM_LEN ) ,
    .IR_OPCODE ( RAM_OP  ) )
    ram_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( ram_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( ram_out         ) ,
      .dr_data_in      ( ram_in          ) );

  // ---------------------------------------------------------------------------------
  // KEY_OP
  // 

  wire               key_tdo;
  wire [KEY_LEN-1:0] key_out;
  wire [KEY_LEN-1:0] key_in;

  assign { o_key_enc_ram, o_key_enc_rf, o_key_scr_ram, o_key_scr_rf } = key_out;
  assign key_in = key_out;

  jtag_reg #(
    .DR_LEN    ( KEY_LEN ) ,
    .IR_OPCODE ( KEY_OP  ) )
    key_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( key_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( key_out         ) ,
      .dr_data_in      ( key_in          ) );

  // ---------------------------------------------------------------------------------
  // CLK_OP
  // 

  wire               clk_tdo;
  wire [CLK_LEN-1:0] clk_out;
  wire [CLK_LEN-1:0] clk_in;

  wire clk_notconn;

  assign { o_clk_osc_en,
           o_clk_sel_src,
           o_clk_gbl_en,
           clk_notconn,
           o_clk_mem_en,
           o_clk_rng_en,
           o_clk_smp_en,
           o_clk_cmo_en,
           o_clk_dlo_en,
           o_clk_pln_en,
           o_clk_sys_div,
           o_clk_smp_div,
           o_clk_pch_rfs,
           o_clk_rnd_sel,
           o_clk_rnd_ptb_en,
           o_clk_rnd_ptb_gamma } = clk_out;

  assign clk_in              = clk_out;

  jtag_reg #(
    .DR_LEN    ( CLK_LEN ) ,
    .IR_OPCODE ( CLK_OP  ) )
    clk_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( clk_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( clk_out         ) ,
      .dr_data_in      ( clk_in          ) );

  // ---------------------------------------------------------------------------------
  // FLK_OP
  // 

  wire flk_tdo;
  wire flk_out;
  wire flk_in;

  assign o_clk_flk_bit = flk_out;
  assign flk_in       = flk_out;

  jtag_reg #(
    .DR_LEN    ( FLK_LEN ) ,
    .IR_OPCODE ( FLK_OP  ) )
    flk_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( flk_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( flk_out         ) ,
      .dr_data_in      ( flk_in          ) );
  
  // ---------------------------------------------------------------------------------
  // RNG_OP
  // 

  wire               rng_tdo;
  wire [RNG_LEN-1:0] rng_out;
  wire [RNG_LEN-1:0] rng_in;

  assign { o_rng_psd_en,
           o_rng_osc_en,
           o_rng_osc_jit_en,
           o_rng_osc_jit_div,
           o_rng_ptb_en,
           o_rng_use_seed,
           o_rng_seed } = rng_out;

  assign rng_in = {o_rng_psd_en,
                   o_rng_osc_en,
                   o_rng_osc_jit_en,
                   o_rng_osc_jit_div,
                   o_rng_ptb_en,
                   o_rng_use_seed,
                   i_rng_state};

  jtag_reg #(
    .DR_LEN    ( RNG_LEN ) ,
    .IR_OPCODE ( RNG_OP  ) )
    rng_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( rng_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( rng_out         ) ,
      .dr_data_in      ( rng_in          ) );

  // ---------------------------------------------------------------------------------
  // STA_OP
  // 

  wire               sta_tdo;
  wire [STA_LEN-1:0] sta_out;
  wire [STA_LEN-1:0] sta_in;

  wire [3:0] sta_output_nc;

  assign { sta_output_nc, o_sta_q_src } = sta_out;
  assign sta_in = {i_clk_initdone, i_rng_initdone, 1'b0, i_q};

  jtag_reg #(
    .DR_LEN    ( STA_LEN ) ,
    .IR_OPCODE ( STA_OP  ) )
    sta_reg (
      .tck             ( tck             ) ,
      .tdi             ( tdi             ) ,
      .tdo             ( sta_tdo         ) ,
      .rst_n           ( rst_n           ) ,
      .state_tlr       ( state_tlr       ) ,
      .state_capturedr ( state_capturedr ) ,
      .state_shiftdr   ( state_shiftdr   ) ,
      .state_updatedr  ( state_updatedr  ) ,
      .ir_reg          ( ir_reg          ) ,
      .dr_data_out     ( sta_out         ) ,
      .dr_data_in      ( sta_in          ) );

  // ---------------------------------------------------------------------------------
  // more jtag logic
  //

  wire ir_tdo;
  assign ir_tdo = ir_reg[0];
  always @(posedge tck or negedge rst_n) begin
    if(!rst_n) begin
      ir_reg <= IDCODE_OP;
    end else if(state_tlr) begin
      ir_reg <= IDCODE_OP;
    end else if(state_captureir) begin
      ir_reg <= 4'b0000;
    end else if(state_shiftir) begin
      ir_reg <= {tdi, ir_reg[3:1]};
    end
  end

  // IR selects the appropriate DR
  reg tdo_pre;
  always @* begin
    tdo_pre = 1'b0;
    if(state_shiftdr) begin
      case(ir_reg)
        IDCODE_OP:   tdo_pre = idcode_tdo;
        BYPASS_OP:   tdo_pre = bypass_tdo;
        RAM_OP:      tdo_pre = ram_tdo;
        RF_OP:       tdo_pre = rf_tdo;
        CLK_OP:      tdo_pre = clk_tdo;
        RNG_OP:      tdo_pre = rng_tdo;
        STA_OP:      tdo_pre = sta_tdo;
        default:     tdo_pre = bypass_tdo;
      endcase
    end else if(state_shiftir) begin
      tdo_pre = ir_tdo;
    end
  end

  // TDO updates on the negative edge according to the spec
  always @(negedge tck or negedge rst_n)
    if (!rst_n) tdo <= 1'b0;
    else        tdo <= tdo_pre;

endmodule

