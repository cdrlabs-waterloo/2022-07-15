## reads in the DLO_MAX_DEPTH variable (this file is gen automatically by synth)
source "../synth_dlo/work/dlo_synth_defines.tcl"

## Set time and capacitance units (first thing!)
set_units -capacitance {1pF} -time {1ns}

##
## Uses the osc frequencies at the fast corner with system clock divider set to
## position one, which selects a 180 MHz system clock. Comments on the oscillator
## frequencies can me found in their respective verilog models.
##

set TCK_PERIOD  20
set OSC_PERIOD  3.55
set RNG_PERIOD  2.2

##
## >> Set case analysis: OSCILLATOR CLOCK!
##
## U_TST:
##   o_sta_q_src              // select between osc clocks and servant gpio
##
## U_CLKG:
##   i_clk_osc_en             // oscillator enable
##   i_clk_flk_bit            // `fake` clock from jtag (allows step-by-step ex)
##   i_clk_sel_src            // clock source select (osc=1,tck=0,flk=2)
##   i_clk_gbl_en             // global clock enable
##   i_clk_mem_en             // mem clock enable
##   i_clk_rng_en             // rng clock enable
##   i_clk_smp_en             // sampling clock enable
##   i_clk_cmo_en             // servant cmo (CMOS) clock enable
##   i_clk_dlo_en             // servant dlo (domino) clock enable
##   i_clk_pln_en             // servant pln (plaintext) clock enable
##   i_clk_sys_div            // system clock divider
##   i_clk_smp_div            // sampling clock divider for rng
##   i_clk_pch_rfs            // enable refresh precharge cycles when clk is skipped
##
## U_RNG:
##   i_rng_osc_en             // enables rng oscillator
##   i_rng_osc_jit_en         // enables jitter measurement
##   i_rng_osc_jit_div        // clock divider for jitter meas
##

set_case_analysis   {0}   {U_TST/o_sta_q_src}

set_case_analysis   {1}   {U_CLKG/i_clk_osc_en}
set_case_analysis   {0}   {U_CLKG/i_clk_flk_bit}

set_case_analysis   {1}   {U_CLKG/i_clk_sel_src[0]}
set_case_analysis   {0}   {U_CLKG/i_clk_sel_src[1]}

set_case_analysis   {1}   {U_CLKG/i_clk_gbl_en}
set_case_analysis   {1}   {U_CLKG/i_clk_mem_en}
set_case_analysis   {1}   {U_CLKG/i_clk_rng_en}
set_case_analysis   {1}   {U_CLKG/i_clk_smp_en}
set_case_analysis   {1}   {U_CLKG/i_clk_cmo_en}
set_case_analysis   {1}   {U_CLKG/i_clk_dlo_en}
set_case_analysis   {1}   {U_CLKG/i_clk_pln_en}

set_case_analysis   {1}   {U_CLKG/i_clk_sys_div[0]}
set_case_analysis   {0}   {U_CLKG/i_clk_sys_div[1]}
set_case_analysis   {0}   {U_CLKG/i_clk_sys_div[2]}

set_case_analysis   {0}   {U_CLKG/i_clk_smp_div[0]}
set_case_analysis   {0}   {U_CLKG/i_clk_smp_div[1]}
set_case_analysis   {0}   {U_CLKG/i_clk_smp_div[2]}

set_case_analysis   {1}   {U_CLKG/i_clk_pch_rfs}

set_case_analysis   {1}   {U_RNG/i_rng_osc_en}
set_case_analysis   {1}   {U_RNG/i_rng_osc_jit_en}

set_case_analysis   {0}   {U_RNG/i_rng_osc_jit_div[0]}
set_case_analysis   {0}   {U_RNG/i_rng_osc_jit_div[1]}
set_case_analysis   {0}   {U_RNG/i_rng_osc_jit_div[2]}

##
## Create main clock sources (osc, rng osc, and jtag)
##

create_clock -name   clk_osc \
             -period $OSC_PERIOD \
             [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"]

create_clock -name   clk_rng_osc \
             -period $RNG_PERIOD \
             [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"]

create_clock -name   jtag_tck \
             -period $TCK_PERIOD \
             [get_ports HGO_TCK]

##
## System clock divider
##

create_generated_clock -name      "clk_sys_div2" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 2 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div2"]

create_generated_clock -name      "clk_sys_div4" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 4 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div4"]

create_generated_clock -name      "clk_sys_div8" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div8"]

create_generated_clock -name      "clk_sys_div16" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 16 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div16"]

create_generated_clock -name      "clk_sys_div32" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 32 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div32"]

create_generated_clock -name      "clk_sys_div64" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 64 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div64"]

create_generated_clock -name      "clk_sys_div128" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 128 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div128"]

create_generated_clock -name      "clk_sys_div256" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 256 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/U_CLK_DIV/o_clk_div256"]

##
## Sampling clock divider
##


create_generated_clock -name      "clk_smp_div2" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 2 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div2"]

create_generated_clock -name      "clk_smp_div4" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 4 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div4"]

create_generated_clock -name      "clk_smp_div8" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div8"]

create_generated_clock -name      "clk_smp_div16" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 16 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div16"]

create_generated_clock -name      "clk_smp_div32" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 32 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div32"]

create_generated_clock -name      "clk_smp_div64" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 64 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div64"]

create_generated_clock -name      "clk_smp_div128" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 128 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div128"]

create_generated_clock -name      "clk_smp_div256" \
                       -source    [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"] \
                       -divide_by 256 \
                       [get_pins "U_CLKG/U_CLKDIV_SMP/U_CLK_DIV/o_clk_div256"]

##
## RNG clock divider
##

create_generated_clock -name      "clk_rng_div2" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 2 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div2"]

create_generated_clock -name      "clk_rng_div4" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 4 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div4"]

create_generated_clock -name      "clk_rng_div8" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div8"]

create_generated_clock -name      "clk_rng_div16" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 16 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div16"]

create_generated_clock -name      "clk_rng_div32" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 32 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div32"]

create_generated_clock -name      "clk_rng_div64" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 64 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div64"]

create_generated_clock -name      "clk_rng_div128" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 128 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div128"]

create_generated_clock -name      "clk_rng_div256" \
                       -source    [get_pins "U_RNG/U_RNG_OSC_DRV/ZN"] \
                       -divide_by 256 \
                       [get_pins "U_RNG/U_CLKDIV_RNG/U_CLK_DIV/o_clk_div256"]


##
## Other generated clocks
##

create_generated_clock -name      "clk_mem" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/o_clk_mem"]

create_generated_clock -name      "clk_rng" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/o_clk_rng"]

create_generated_clock -name      "clk_smp" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/o_clk_smp"]

create_generated_clock -name      "clk_cmo" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/o_clk_cmo"]

create_generated_clock -name      "clk_dlo" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/o_clk_dlo"]

create_generated_clock -name      "clk_pch" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       -invert \
                       [get_pins "U_CLKG/o_clk_pch"]

create_generated_clock -name      "clk_pln" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 8 \
                       [get_pins "U_CLKG/o_clk_pln"]

create_generated_clock -name      "clk_sys_tap" \
                       -source    [get_pins "U_CLKG/U_CLK_OSC_DRV/ZN"] \
                       -divide_by 4 \
                       [get_pins "U_CLKG/U_CLKDIV_SYS/o_clk_div"]


##
## Set false paths accross clock domains
##

set lst_clk_osc { "clk_osc"
                  "clk_mem"
                  "clk_rng"
                  "clk_smp"
                  "clk_cmo"
                  "clk_dlo"
                  "clk_pch"
                  "clk_pln"
                  "clk_sys_tap"
                  "clk_sys_div2"
                  "clk_sys_div4"
                  "clk_sys_div8"
                  "clk_sys_div16"
                  "clk_sys_div32"
                  "clk_sys_div64"
                  "clk_sys_div128"
                  "clk_sys_div256"
                  "clk_smp_div2"
                  "clk_smp_div4"
                  "clk_smp_div8"
                  "clk_smp_div16"
                  "clk_smp_div32"
                  "clk_smp_div64"
                  "clk_smp_div128"
                  "clk_smp_div256" }

set lst_clk_rng_osc { "clk_rng_osc"
                      "clk_rng_div2"
                      "clk_rng_div4"
                      "clk_rng_div8"
                      "clk_rng_div16"
                      "clk_rng_div32"
                      "clk_rng_div64"
                      "clk_rng_div128"
                      "clk_rng_div256" }

set lst_jtag_tck    { "jtag_tck"    }

set_clock_groups -name cg_clk_osc_clk_rng_osc   -asynchronous -group $lst_clk_osc -group $lst_clk_rng_osc
set_clock_groups -name cg_clk_osc_jtag_tck      -asynchronous -group $lst_clk_osc -group $lst_jtag_tck

set_clock_groups -name cg_clk_rng_osc_jtag_tck  -asynchronous -group $lst_clk_rng_osc -group $lst_jtag_tck

##
## Constraints on input/output delays and transitions
##

set_input_delay  -clock jtag_tck [expr $TCK_PERIOD * 0.25] [get_ports HGO_TMS]
set_input_delay  -clock jtag_tck [expr $TCK_PERIOD * 0.25] [get_ports HGO_TDI]
set_input_delay  -clock jtag_tck [expr $TCK_PERIOD * 0.25] [get_ports HGO_RSTN]

set_output_delay -clock jtag_tck [expr $TCK_PERIOD * 0.25] [get_ports HGO_TDO]

set_false_path -to [get_ports "HGO_Q0"]
set_false_path -to [get_ports "HGO_Q1"]

set_clock_transition -rise 0.1 [all_clocks]
set_clock_transition -fall 0.1 [all_clocks]

set_clock_uncertainty -setup 0.1 [all_clocks]
set_clock_uncertainty -hold  0.1 [all_clocks]

## Max transition copied from library
set_max_transition   0.5    [current_design]

## Reasonable input transition
set_input_transition 0.2    [all_inputs]

## Output load from output PAD (=0.0945 + 40% safety margin)
set_load             0.1323 [all_outputs]

