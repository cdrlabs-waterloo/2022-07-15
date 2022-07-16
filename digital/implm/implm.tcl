## set max cpus to use for innovus
set_multi_cpu_usage -local_cpu 8

set top_cmo                      "U_SERVANT_TOP/U_SERVANT_CMO"
set top_dlo                      "U_SERVANT_TOP/U_SERVANT_DLO"
set top_pln                      "U_SERVANT_TOP/U_SERVANT_PLN"

## remove don't touch before connect_global nets, otherwise cells in masked
## servants will have no power/ground pins
set_db "hinst:hgo_top/$top_cmo"     .dont_touch false
set_db "hinst:hgo_top/$top_dlo"     .dont_touch false

delete_assigns -ignore_port_constraints -report

puts "*WARNING: ensure previous `delete_assigns` command did not insert buffers"

delete_dangling_ports
delete_empty_hinsts

puts "*WARNING: ensure previous `delete_empty_hinsts` removed only irrelevant cells"

set insts [get_db insts $top_cmo/*]
foreach inst $insts {
    set_db $inst .dont_touch size_ok
}

set insts [get_db insts $top_dlo/*]
foreach inst $insts {
    set_db $inst .dont_touch size_ok
    set cell [get_db $inst .base_cell.base_name]
    if { $cell == "AO_DLO_D0" || $cell == "AO_DLO_D1" || $cell == "XOR_DLO_D0"  || $cell == "XOR_DLO_D1"  || $cell == "XOR_DLO_D2" } {
        set_db pin:[get_db $inst .name]/CP .cts_sink_type through
    }
}

## Enable conservative optimizations
set_db opt_fix_fanout_load           {false}
set_db opt_area_recovery             {false}
set_db opt_constant_nets             {false}
set_db opt_delete_insts              {true}
set_db opt_detail_drv_failure_reason {true}
set_db opt_preserve_hpin_function    {false}
set_db opt_enable_restructure        {false}
set_db opt_move_insts                {false}
set_db opt_pin_swapping              {true}
set_db opt_remove_redundant_insts    {false}
set_db opt_unfix_clock_insts         {false}
set_db opt_fix_hold_verbose          {true}
set_db opt_hold_target_slack         {0.020}

#set_db cts_update_clock_latency {false}

## Set max routing layer (leave 8 and 9 for power grid)
set_db route_design_top_routing_layer 7

## forces router to use vias instead of relying on connections inside ip blocks
set_db route_design_allow_pin_as_feedthru {none}

## Do placement and routing (pre-CTS)
enable_metrics -on
place_opt_design

## Check for major errors on placement/timing/pins
check_design -type {place pin_assign}

## Save database with placement and routing (pre clock tree)
write_db prects-db

## extract spef (parasitics) file from current layout
write_parasitics -spef_file top.spef -rc_corner rc_corner

## perform timing analysis
time_design -pre_cts \
            -path_report \
            -drv_report \
            -slack_report \
            -num_paths 50 \
            -report_prefix preCTS \
            -report_dir timingReports

## add tie-cells (other option is to connect all to the VDD/VSS)
add_tieoffs -lib_cell "TIEH TIEL"

## optimize the design
opt_design -pre_cts
opt_design -pre_cts -drv

## create clock tree spec and source it
create_clock_tree_spec -out_file ccopt.spec 
source ccopt.spec

set_db cts_buffer_cells {CKBD0 CKBD1 CKBD2 CKBD3 CKBD4 CKBD6 CKBD8 CKBD12 CKBD16 CKBD20 CKBD24}

## inserts clock tree exclusion buffers so that hold time fixes can be performed
## when clock is used as data (this is important for domino logic gates)
#add_clock_tree_exclusion_drivers

## run the cts with default rules
ccopt_design

## optimize the design
opt_design -post_cts
opt_design -post_cts -drv
opt_design -post_cts -hold

## check the results of the cts synthesis
time_design -post_cts

## check for hold violations now
time_design -post_cts -hold

set_db route_design_detail_fix_antenna      true
set_db route_design_antenna_diode_insertion true
set_db route_design_antenna_cell_name       {ANTENNA}
set_db route_design_with_timing_driven      true
set_db route_design_with_si_driven          true
set_db route_design_with_timing_driven      true
set_db route_design_with_si_driven          true

route_design -global_detail
write_db route-db

## evaluate timing after routing
set_db timing_analysis_type ocv
set_db timing_analysis_cppr both

time_design -post_route
opt_design -post_route
opt_design -post_route -drv

## optimize the design
time_design -post_route -hold
opt_design -post_route -hold

## run the drc and connectivity error checker (do not replace drc/lvs)
check_drc
check_connectivity -ignore_dangling_wires

## Add filler cells
add_fillers -base_cells {FILL1 FILL2 FILL4 FILL8 FILL16 FILL32 FILL64} \
            -check_drc true \
            -check_min_hole true \
            -check_via_enclosure true \
            -prefix FILLER_CORE

## run the drc and connectivity error checker (do not replace drc/lvs)
check_drc
check_connectivity -ignore_dangling_wires

## generate basic reports
report_timing -late  -nworst 50 > timing_late.rpt
report_timing -early -nworst 50 > timing_early.rpt
report_constraint -drv_violation_type max_transition  > drv_maxtran.rpt
report_constraint -drv_violation_type max_capacitance > drv_maxcap.rpt

## run several checks on the design
source ../checks.tcl

report_dangling_nets
dangling_input_pins
dangling_out_pins
floating_instances
floating_io_ports
noclock_waveform 

## save database inserting filler cells
write_db signoff-db

## Write out DEF file for importing into Virtuoso
write_def -routing -unit 1000 top.def

## write delay file for all mmmc views
write_sdf -target_application verilog top_functional_slow.sdf    -view view_functional_wcl_slow
write_sdf -target_application verilog top_functional_fast.sdf    -view view_functional_wcl_fast
write_sdf -target_application verilog top_functional_typical.sdf -view view_functional_wcl_typical

## write netlist for lvs checking (remove stdcells definition, bond pads, and fillers)
write_netlist top.v
write_netlist \
    -phys \
    -exclude_leaf_cells \
    -include_pg_ports \
    -exclude_insts_of_cells {artisan_rf artisan_ram FILL1 FILL2 FILL4 FILL8 FILL16 FILL32 FILL64} \
    top_lvs.v 

## NOTE: due to a PG bug in the block level design, PG ports need to be added
##       manually to the top_lvs.v netlist.

