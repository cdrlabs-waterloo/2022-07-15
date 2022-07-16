`default_nettype none

/* This random number generator was inspired on
 * the work of Thomas Tkacik, CHES 2002.
 */

module casr37(input  wire        clk,
              input  wire        rst_n,
              input  wire        i_en,
              input  wire        i_ptb,
              input  wire        i_ptb_valid,
              input  wire        i_si,
              input  wire        i_sr_valid,
              input  wire [36:0] i_state,
              input  wire        i_load_state,
              output wire        o_so,
              output reg  [36:0] o_state);

  wire [36:0] nxt_state;

  integer idx;

  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      o_state <= 37'b0;
    else
      if (i_en)
        for (idx = 0; idx < 37; idx = idx+1)
          o_state[idx] <= nxt_state[idx];
      else begin
        if (i_load_state)
          o_state <= i_state;
        else if (i_sr_valid)
          o_state <= {o_state[35:0], i_si};
      end

  genvar  i;

  generate
    // From: Cattell 1995, JET, matches the model in `digital/python/casr.py`
    for (i = 1; i <= 37; i = i+1) begin : casr_blk
      wire left  = (i > 1)  ? o_state[37-i+1] : i_ptb & i_ptb_valid; // perturbed instead of null terminated
      wire right = (i < 37) ? o_state[37-i-1] : i_ptb & i_ptb_valid; // perturbed instead of null terminated
      assign nxt_state[37-i] = (i == 9) ? left ^ right ^ o_state[37-9] : left ^ right;
    end
  endgenerate

  assign o_so = o_state[36];

endmodule

module lfsr43(input  wire        clk,
              input  wire        rst_n,
              input  wire        i_en,
              input  wire        i_ptb,
              input  wire        i_ptb_valid,
              input  wire        i_si,
              input  wire        i_sr_valid,
              input  wire [42:0] i_state,
              input  wire        i_load_state,
              output wire        o_so,
              output reg  [42:0] o_state);

  wire feedback;

  // the indexes are the table values from xapp052.pdf (decrement 1)
  assign feedback = (~(o_state[42] ^
                       o_state[41] ^
                       o_state[37] ^
                       o_state[36])) ^ (i_ptb & i_ptb_valid);

  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      o_state <= 43'b0;
    else
      if (i_en)
        o_state <= {o_state[41:0], feedback};
      else begin
        if (i_load_state)
          o_state <= i_state;
        else if (i_sr_valid)
          o_state <= {o_state[41:0], i_si};
      end

  assign o_so = o_state[42];

endmodule


module rng
  #(parameter NINVERTER = 66)
  (
   input  wire                 clk_rng,           // rng clock (no cycles skipped)
   input  wire                 clk_smp,           // clock for sampling the osc (low freq)
   input  wire                 rst_n,             // async reset
   input  wire                 i_rng_psd_en,      // enables the pseudo-rng (post-proc)
   input  wire                 i_rng_osc_en,      // enables rng oscillator
   input  wire                 i_rng_osc_jit_en,  // enables jitter measurement
   input  wire [2:0]           i_rng_osc_jit_div, // clock divider for jitter meas
   input  wire                 i_rng_ptb_en,      // enables sampling & perturbation of lfsr/casr
   input  wire                 i_rng_use_seed,    // use input seed for initialization
   input  wire [79:0]          i_rng_seed,        // load state with provided seed
   output wire                 o_rng_osc_jit,     // divided osc clock for jitter meas
   output wire [79:0]          o_rng_state,       // rng state
   output reg                  o_rng_initdone);   // rng init done signal

  reg       rndbit_sample;
  reg [1:0] rndbit_meta;
  reg       rndbit_valid;
  wire      rndbit;

  wire      clk_osc;
  wire      clk_osc_pre;

  reg [1:0] clk_smp_trn;

  wire      rndbit_lfsr_out;

  reg [6:0] cnter;

  // ------------------------------------------------------------ 
  // random bit sampling logic
  //

  INVLONG_OSC23 U_RNG_OSC(
    .EN  ( i_rng_osc_en ) ,
    .OUT ( clk_osc_pre  ) );

  /* it is hard to tell innovus/liberate the driving strength of the
   * oscillator, puting a fixed buffer on the output is much easier */
  INVD2 U_RNG_OSC_DRV(
    .I  ( clk_osc_pre ),
    .ZN ( clk_osc     ) );

  clkdiv U_CLKDIV_RNG(
    .clk        ( clk_osc           ) ,
    .rst_n      ( rst_n             ) ,
    .i_en       ( i_rng_osc_jit_en  ) ,
    .i_div      ( i_rng_osc_jit_div ) ,
    .o_clk_div  ( o_rng_osc_jit     ) ,
    .o_clk_all  ( /* Not Con */     ) );

  always @(posedge clk_smp or negedge rst_n)
    if (!rst_n) rndbit_sample <= 1'b0;
    else        rndbit_sample <= clk_osc;

  always @(posedge clk_rng or negedge rst_n)
    if (!rst_n) clk_smp_trn <= 2'b0;
    else        clk_smp_trn <= { clk_smp_trn[0], clk_smp };

  always @(posedge clk_rng or negedge rst_n)
    if (!rst_n) begin
      rndbit_meta  <= 2'b0;
      rndbit_valid <= 1'b0;
    end else begin
      rndbit_meta  <= {rndbit_meta[0], rndbit_sample};
      rndbit_valid <= (clk_smp_trn == 2'b01) & i_rng_osc_en;
    end
  
  assign rndbit = rndbit_meta[1];

  // ------------------------------------------------------------ 
  // instantiates the pseudo RNGs and generates init done signal
  //

  lfsr43 U_LFSR43(
    .clk          ( clk_rng                          ) ,
    .rst_n        ( rst_n                            ) ,
    .i_en         ( i_rng_psd_en & o_rng_initdone    ) ,
    .i_ptb        ( rndbit                           ) ,
    .i_ptb_valid  ( rndbit_valid & i_rng_ptb_en      ) ,
    .i_si         ( rndbit                           ) ,
    .i_sr_valid   ( rndbit_valid & (~i_rng_use_seed) ) ,
    .i_state      ( i_rng_seed[42:0]                 ) ,
    .i_load_state ( i_rng_use_seed                   ) ,
    .o_so         ( rndbit_lfsr_out                  ) ,
    .o_state      ( o_rng_state[42:0]               ) );

  casr37 U_CASR37(
    .clk          ( clk_rng                          ) ,
    .rst_n        ( rst_n                            ) ,
    .i_en         ( i_rng_psd_en & o_rng_initdone    ) ,
    .i_ptb        ( rndbit                           ) ,
    .i_ptb_valid  ( rndbit_valid & i_rng_ptb_en      ) ,
    .i_si         ( rndbit_lfsr_out                  ) ,
    .i_sr_valid   ( rndbit_valid & (~i_rng_use_seed) ) ,
    .i_state      ( i_rng_seed[79:43]                 ) ,
    .i_load_state ( i_rng_use_seed                   ) ,
    .o_so         ( /* Not Conn. */                  ) ,
    .o_state      ( o_rng_state[79:43]                ) );


  always @(posedge clk_rng or negedge rst_n)
    if (!rst_n)                                 cnter <= 7'b0;
    else if (rndbit_valid && (!o_rng_initdone)) cnter <= cnter + 1'b1;

  always @(posedge clk_rng or negedge rst_n)
    if (!rst_n)                                  o_rng_initdone <= 1'b0;
    else if ((cnter >= 7'd80) || i_rng_use_seed) o_rng_initdone <= 1'b1;
  
endmodule

