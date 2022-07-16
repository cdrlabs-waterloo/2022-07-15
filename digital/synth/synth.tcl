## Set some paths definitions
set_db init_lib_search_path      "path/to/tech/lib \
                                  $env(ROOT_DIR)/library/liberate/dlo/lib \
                                  $env(ROOT_DIR)/digital/ips/rf \
                                  $env(ROOT_DIR)/digital/ips/ram \
                                  \
                                  path/to/tech/lef \
                                  $env(ROOT_DIR)/library/lef/dlo/lef \
                                  \
                                  path/to/tech/captable"


set_db init_hdl_search_path      "$env(ROOT_DIR)/digital/rtl \
                                  $env(ROOT_DIR)/digital/synth/synth_cmo/work \
                                  $env(ROOT_DIR)/digital/synth/synth_dlo/work"

set top_cmo                      "hgo_top/U_SERVANT_TOP/U_SERVANT_CMO"
set top_dlo                      "hgo_top/U_SERVANT_TOP/U_SERVANT_DLO"
set top_pln                      "hgo_top/U_SERVANT_TOP/U_SERVANT_PLN"

## Number of CPUs for synthesis, effort and debuging level
set_db max_cpus_per_server 8 

set_db syn_generic_effort {medium}
set_db syn_map_effort     {medium}
set_db syn_opt_effort     {medium}

set_db information_level   9 

## Set design process node
set_db / .design_process_node {65}

## Creates the MMMC flow
set_db pbs_mmmc_flow    {true}
read_mmmc ../mmmc.tcl

## used by connect_global_nets
set_db init_power_nets VDD
set_db init_ground_nets VSS

## Read physical information
read_physical -lef {tech.lef hgo_library_dlo.lef}

## Enable debugging on Genus / impacts runtime
set_db / .hdl_track_filename_row_col true

## Preserve hierarchies
set_db / .auto_ungroup {none}

## Read RTL and elaborate
read_hdl -f ../../rtl/filelist.l

## Reads in the servant netlists
read_hdl -library libcmo   ../synth_cmo/work/netlist.v
read_hdl -library libdlo   ../synth_dlo/work/netlist.v
read_hdl -library libpln   ../synth_pln/work/netlist.v

## Elaborate the configuration defined in the rtl
elaborate cfg

## Apply CPF power definitions
read_power_intent -cpf ../power.cpf
commit_power_intent

## Initialize the design
init_design
check_design -unresolved

puts "Check SDC reading in for errors and enter <resume> to continue."
suspend

set_db inst:hgo_top/U_CLKG/U_CLK_OSC_DRV              .dont_touch {true}
set_db inst:hgo_top/U_RNG/U_RNG_OSC_DRV               .dont_touch {true}

set_db inst:hgo_top/U_CLKG/U_CLKDIV_SYS/U_CLK_GATE    .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLKDIV_SMP/U_CLK_GATE    .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_MUX2_JTAG_OSC            .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_MUX2_JTAG_FCK            .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLK_GATE_MEM             .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLK_GATE_RNG             .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLK_GATE_SMP             .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLK_GATE_CMO             .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLK_GATE_DLO             .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLK_GATE_PCH             .dont_touch {size_ok}
set_db inst:hgo_top/U_CLKG/U_CLK_GATE_PLN             .dont_touch {size_ok}

## Avoid optmizations on the masking logic (not needed on pln)
## It needs to be applied to the hier instance so that nets are
## also preserved. Clock and reset will have preserves removed
## during physical implm.

set_db "hinst:$top_cmo" .dont_touch size_ok
set_db "hinst:$top_dlo" .dont_touch size_ok

## Set synthesis mode to physical layout estimation
set_db / .interconnect_mode {ple}

report_ple

## Physical implementation requires uniquified netlist
## (preserved blocks must be uniquified already)
uniquify hgo_top -verbose

## Start synthesis
syn_generic
syn_map
syn_opt

## Save some reports
report_area              > area.rpt
report_gates             > gates.rpt
report_timing            > timing.rpt
report_clocks -generated > clocks.rpt

## Save the design
write_db synth-db

## Write output files
write_hdl hgo_top > netlist.v

## Save the delay file
write_sdf -edges check_edge -setuphold merge_when_paired -recrem merge_when_paired > top.sdf

## Write output files
write_design -innovus hgo_top

