`default_nettype none

module clkdiv256(input wire clk,
                 input wire rst_n,
                 output reg o_clk_div2,
                 output reg o_clk_div4,
                 output reg o_clk_div8,
                 output reg o_clk_div16,
                 output reg o_clk_div32,
                 output reg o_clk_div64,
                 output reg o_clk_div128,
                 output reg o_clk_div256);

  always @(posedge clk or negedge rst_n)
    if (!rst_n) o_clk_div2 <= 1'b0;
    else        o_clk_div2 <= ~o_clk_div2;

  always @(posedge o_clk_div2 or negedge rst_n)
    if (!rst_n) o_clk_div4 <= 1'b0;
    else        o_clk_div4 <= ~o_clk_div4;

  always @(posedge o_clk_div4 or negedge rst_n)
    if (!rst_n) o_clk_div8 <= 1'b0;
    else        o_clk_div8 <= ~o_clk_div8;

  always @(posedge o_clk_div8 or negedge rst_n)
    if (!rst_n) o_clk_div16 <= 1'b0;
    else        o_clk_div16 <= ~o_clk_div16;

  always @(posedge o_clk_div16 or negedge rst_n)
    if (!rst_n) o_clk_div32 <= 1'b0;
    else        o_clk_div32 <= ~o_clk_div32;

  always @(posedge o_clk_div32 or negedge rst_n)
    if (!rst_n) o_clk_div64 <= 1'b0;
    else        o_clk_div64 <= ~o_clk_div64;

  always @(posedge o_clk_div64 or negedge rst_n)
    if (!rst_n) o_clk_div128 <= 1'b0;
    else        o_clk_div128 <= ~o_clk_div128;

  always @(posedge o_clk_div128 or negedge rst_n)
    if (!rst_n) o_clk_div256 <= 1'b0;
    else        o_clk_div256 <= ~o_clk_div256;

endmodule

module clkdiv(input  wire       clk,
              input  wire       rst_n,
              input  wire       i_en,
              input  wire [2:0] i_div,
              output reg        o_clk_div,
              output wire [7:0] o_clk_all);
  wire clk_pre;

  wire clk_div2;
  wire clk_div4;
  wire clk_div8;
  wire clk_div16;
  wire clk_div32;
  wire clk_div64;
  wire clk_div128;
  wire clk_div256;

  CKLNQD1 U_CLK_GATE(
    .TE ( 1'b0    ) ,
    .E  ( i_en    ) ,
    .CP ( clk     ) ,
    .Q  ( clk_pre ) );

  clkdiv256 U_CLK_DIV(
    .clk          ( clk_pre    ) ,
    .rst_n        ( rst_n      ) ,
    .o_clk_div2   ( clk_div2   ) ,
    .o_clk_div4   ( clk_div4   ) ,
    .o_clk_div8   ( clk_div8   ) ,
    .o_clk_div16  ( clk_div16  ) ,
    .o_clk_div32  ( clk_div32  ) ,
    .o_clk_div64  ( clk_div64  ) ,
    .o_clk_div128 ( clk_div128 ) ,
    .o_clk_div256 ( clk_div256 ) );

  always @*
    case (i_div)
      3'd0: o_clk_div = clk_div2;
      3'd1: o_clk_div = clk_div4;
      3'd2: o_clk_div = clk_div8;
      3'd3: o_clk_div = clk_div16;
      3'd4: o_clk_div = clk_div32;
      3'd5: o_clk_div = clk_div64;
      3'd6: o_clk_div = clk_div128;
      3'd7: o_clk_div = clk_div256;
      default: o_clk_div = clk_div2;
    endcase

  assign o_clk_all = { clk_div256,
                       clk_div128,
                       clk_div64,
                       clk_div32,
                       clk_div16,
                       clk_div8,
                       clk_div4,
                       clk_div2 };

endmodule

module mux8(input  wire [2:0] i_sel,
            input  wire [7:0] i_in,
            output wire       o_out);
  assign o_out = i_in[i_sel];
endmodule

module lfsr8(input wire        clk,
             input wire        rst_n,
             input wire        i_en,
             input wire        i_ptb,
             input wire        i_ptb_valid,
             input wire        i_si,
             input wire        i_sr_valid,
             output reg [7:0]  o_state,
             output wire       o_p25,
             output wire       o_p50,
             output wire       o_p75);

  wire feedback;

  // the indexes are the table values from xapp052.pdf (decrement 1)
  assign feedback = (~(o_state[7] ^
                       o_state[5] ^
                       o_state[4] ^
                       o_state[3])) ^ (i_ptb & i_ptb_valid);

  // output signals that will be one 25%, 50%, and 75% of the cycles
  assign o_p25 = o_state[7] & o_state[6];
  assign o_p50 = o_state[7] ^ o_state[6];
  assign o_p75 = o_state[7] | o_state[6];
  
  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      o_state <= 8'b0;
    else
      if (i_en) begin
        /* all ones is the forbidden state, avoids update if it will
         * go to the forbidden state due to the perturbation bit */
        if ((~(&o_state[6:0])) || (~feedback))
          o_state <= {o_state[6:0], feedback};
      end else if (i_sr_valid) o_state <= {o_state[6:0], i_si};

endmodule

module clkg #(parameter NINVERTER = 66) (
   input  wire                 clk_jtag,             // jtag clock
   input  wire                 rst_n,                // async reset
   input  wire                 i_clk_osc_en,         // oscillator enable
   input  wire                 i_clk_flk_bit,        // `fake` clock from jtag (allows step-by-step ex)
   input  wire [1:0]           i_clk_sel_src,        // clock source select (osc=1,tck=0,flk=2)
   input  wire                 i_clk_gbl_en,         // global clock enable
   input  wire                 i_clk_mem_en,         // mem clock enable
   input  wire                 i_clk_rng_en,         // rng clock enable
   input  wire                 i_clk_smp_en,         // sampling clock enable
   input  wire                 i_clk_cmo_en,         // servant cmo (CMOS) clock enable
   input  wire                 i_clk_dlo_en,         // servant dlo (domino) clock enable
   input  wire                 i_clk_pln_en,         // servant pln (plaintext) clock enable
   input  wire [2:0]           i_clk_sys_div,        // system clock divider
   input  wire [2:0]           i_clk_smp_div,        // sampling clock divider for rng
   input  wire                 i_clk_pch_rfs,        // enable refresh precharge cycles when clk is skipped
   input  wire [1:0]           i_clk_rnd_sel,        // clock rand config (b00=0%,b01=25%,b10=50%,b11=75%)
   input  wire                 i_clk_rnd_ptb_en,     // clock rand perturbation enable
   input  wire [7:0]           i_clk_rnd_ptb_gamma,  // clock rand distance between applied perturb
   input  wire                 i_rng_psd_en,         // enables the pseudo-rng (post-proc)
   input  wire                 i_rng_initdone,       // random number gen init completion signal
   input  wire                 i_rng_ptb,            // input perturb bit (always valid)
   output wire                 o_clk_mem,            // clock for memories
   output wire                 o_clk_rng,            // rng clock output (not randomized!)
   output wire                 o_clk_smp,            // rng sampling clock output (low frequency!)
   output wire                 o_clk_cmo,            // clock for servant cmo (CMOS)
   output wire                 o_clk_dlo,            // clock for servant dlo (domino)
   output wire                 o_clk_pch,            // clock for precharge/eval of dynamic logic in dlo
   output wire                 o_clk_pln,            // clock for servant pln (plaintext)
   output reg                  o_clk_initdone);      // clock initialization complete


  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam CHCK = 2'd2;
  localparam RUNN = 2'd3;

  reg  [7:0] gamma_cnter;
  wire [7:0] rnd_state;

  reg [1:0] state;

  wire clk_jtag_fck;

  reg  clk_sys_pre, clk_sys_pre_noskip;
  wire clk_smp;

  reg  rnd_ptb_valid, skip_clk;

  wire clk_rnd_en;

  wire clk_osc, clk_osc_pre, clk_mux_glitch;
  wire p25, p50, p75;
  wire clk_sys_tap;
  wire [7:0] clk_sys_all;

  wire initdone;

  reg clk_dlo_en_late;

  // ------------------------------------------------------------ 
  // this logic is on oscillator clock (careful, high speed!)
  // clock source selection is a 2-step process to avoid
  // glitches, first select the source, then enable it
  //

  INVLONG_OSC37 U_CLK_OSC(
    .EN  ( i_clk_osc_en ),
    .OUT ( clk_osc_pre  ) );

  /* it is hard to tell innovus/liberate the driving strength of the
   * oscillator, puting a fixed buffer on the output is much easier */
  INVD2 U_CLK_OSC_DRV(
    .I  ( clk_osc_pre ),
    .ZN ( clk_osc     ) );

  MUX2D0 U_MUX2_JTAG_OSC(
    .I0( clk_jtag_fck  ),
    .I1( clk_osc          ),
    .S ( i_clk_sel_src[0] ),
    .Z ( clk_mux_glitch   ) );

  MUX2D0 U_MUX2_JTAG_FCK(
    .I0( clk_jtag         ),
    .I1( i_clk_flk_bit    ),
    .S ( i_clk_sel_src[1] ),
    .Z ( clk_jtag_fck  ) );


  clkdiv U_CLKDIV_SYS(
    .clk         ( clk_mux_glitch ) ,
    .rst_n       ( rst_n          ) ,
    .i_en        ( i_clk_gbl_en   ) ,
    .i_div       ( i_clk_sys_div  ) ,
    .o_clk_div   ( clk_sys_tap    ) ,
    .o_clk_all   ( clk_sys_all    ) );

  // ------------------------------------------------------------ 
  // clock randomizer logic
  //

  always @(posedge clk_sys_tap or negedge rst_n)
    if (!rst_n) begin
      gamma_cnter    <= 8'b0;
      rnd_ptb_valid  <= 1'b0;
      o_clk_initdone <= 1'b0;
      state          <= 2'b0;
    end else
      case (state)
        IDLE: begin
          /* if the RNG post processing is disabled, skip lfsr seeding */
          if (i_rng_initdone) begin
            if (i_rng_psd_en) begin
              state         <= INIT;
              rnd_ptb_valid <= 1'b1;
            end else
              state         <= RUNN;
          end
        end
        INIT: begin
          gamma_cnter <= gamma_cnter + 1'b1;
          if (gamma_cnter > 8'hf) begin
            gamma_cnter   <= 8'b0;
            rnd_ptb_valid <= 1'b0;
            state         <= CHCK;
          end
        end
        CHCK: begin
          /* it will repeat init until lfsr loads a state different than
           * all ones. */
          state <= RUNN;
          if ((&rnd_state))
            state <= IDLE;
        end
        RUNN: begin
          o_clk_initdone <= 1'b1;
          if (i_clk_rnd_ptb_en) begin
            gamma_cnter   <= gamma_cnter + 1'b1;
            rnd_ptb_valid <= 1'b0;
            if (gamma_cnter >= i_clk_rnd_ptb_gamma) begin
              gamma_cnter   <= 8'b0;
              rnd_ptb_valid <= 1'b1;
            end
          end
        end
      endcase

  assign clk_rnd_en = (|i_clk_rnd_sel);

  always @*
    case (i_clk_rnd_sel)
        2'b00:   skip_clk = 1'b0;              // never skips a clock cycle
        2'b01:   skip_clk = p25 & initdone;    // skips 25% of clock cycles
        2'b10:   skip_clk = p50 & initdone;    // skips 50% of clock cycles
        2'b11:   skip_clk = p75 & initdone;    // skips 75% of clock cycles
        default: skip_clk = 1'b0;
    endcase

  /*
   *    The `i_clk_pch_rfs` chooses between to modes of operation:
   *
   *    i)  When 0: the precharge clock is generated by directly inverting the
   *        skipped clock (this streches the dynamic logic evaluation window 
   *        and may cause the dynamic charge to leak away).
   *
   *    ii) When 1: dummy precharge refresh clock cycles are inserted when
   *        the main clock is skipped. Rising edges of the main clock are 
   *        synchronized with the precharge clock;
   *        NOTE: This mode was never necessary during chip bringup!
   */

  /* Skips rising edge clock transitions that would occur in a falling edge
   * of the noskip clock. It will be always zero if the noskip clock is being
   * used to generate the precharge clocks (i_clk_pch_rfs=0), or if the clock
   * randomizer is disabled. */

  wire not_insync = (~clk_sys_pre) & clk_sys_pre_noskip & i_clk_pch_rfs & clk_rnd_en;

  always @(posedge clk_sys_tap or negedge rst_n)
    if (!rst_n)
      clk_sys_pre <= 1'b0;
    else if ((~skip_clk) & (~not_insync))
      clk_sys_pre <= ~clk_sys_pre;

  always @(posedge clk_sys_tap or negedge rst_n)
    if (!rst_n) clk_sys_pre_noskip <= 1'b0;
    else        clk_sys_pre_noskip <= ~clk_sys_pre_noskip;

  wire clk_sys_pch     = (i_clk_pch_rfs) ? ~clk_sys_pre_noskip : ~clk_sys_pre;

  clkdiv U_CLKDIV_SMP(
    .clk        ( clk_sys_tap   ) ,
    .rst_n      ( rst_n         ) ,
    .i_en       ( i_clk_smp_en  ) ,
    .i_div      ( i_clk_smp_div ) ,
    .o_clk_div  ( clk_smp       ) ,
    .o_clk_all  ( /* Not Con */ ) );

  lfsr8 U_LFSR8(
    .clk             ( clk_sys_tap                       ) ,
    .rst_n           ( rst_n                             ) ,
    .i_en            ( clk_rnd_en & o_clk_initdone       ) ,
    .i_ptb           ( i_rng_ptb                         ) ,
    .i_ptb_valid     ( rnd_ptb_valid                     ) ,
    .i_si            ( i_rng_ptb                         ) ,
    .i_sr_valid      ( rnd_ptb_valid & (~o_clk_initdone) ) ,
    .o_state         ( rnd_state                         ) ,
    .o_p25           ( p25                               ) ,
    .o_p50           ( p50                               ) ,
    .o_p75           ( p75                               ) );

  assign initdone = i_rng_initdone & o_clk_initdone;

  CKLNQD1 U_CLK_GATE_MEM(
    .TE ( 1'b0         ) ,
    .E  ( i_clk_mem_en ) ,
    .CP ( clk_sys_pre  ) ,
    .Q  ( o_clk_mem    ) );

  CKLNQD1 U_CLK_GATE_RNG(
    .TE ( 1'b0               ) ,
    .E  ( i_clk_rng_en       ) ,
    .CP ( clk_sys_pre_noskip ) ,
    .Q  ( o_clk_rng          ) );

  CKLNQD1 U_CLK_GATE_SMP(
    .TE ( 1'b0         ) ,
    .E  ( i_clk_smp_en ) ,
    .CP ( clk_smp      ) ,
    .Q  ( o_clk_smp    ) );

  CKLNQD1 U_CLK_GATE_CMO(
    .TE ( 1'b0                    ) ,
    .E  ( i_clk_cmo_en & initdone ) ,
    .CP ( clk_sys_pre             ) ,
    .Q  ( o_clk_cmo               ) );

  /*
   * The clock for domino logic is one cycle behind the precharge clock
   * to ensure a reliable first cycle of operation.
   */

  always @(posedge clk_sys_pre or negedge rst_n)
    if (!rst_n) clk_dlo_en_late <= 1'b0;
    else        clk_dlo_en_late <= i_clk_gbl_en & i_clk_dlo_en & initdone;

  CKLNQD1 U_CLK_GATE_DLO(
    .TE  ( 1'b0            ) ,
    .E   ( clk_dlo_en_late ) ,
    .CP  ( clk_sys_pre     ) ,
    .Q   ( o_clk_dlo       ) );

  /*
   * Clock gating cell for precharge clock stays at 1 when disabled,
   * to ensure first cycle will have valid values in the dynamic logic.
   */
  CKLHQD1 U_CLK_GATE_PCH(
    .TE  ( 1'b0                    ) ,
    .E   ( i_clk_dlo_en & initdone ) ,
    .CPN ( clk_sys_pch             ) ,
    .Q   ( o_clk_pch               ) );

  CKLNQD1 U_CLK_GATE_PLN(
    .TE ( 1'b0                    ) ,
    .E  ( i_clk_pln_en & initdone ) ,
    .CP ( clk_sys_pre             ) ,
    .Q  ( o_clk_pln               ) );

endmodule

