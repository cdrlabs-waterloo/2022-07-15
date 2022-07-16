## Set some paths definitions
set_db init_lib_search_path      "path/to/tech/lib \
                                  path/to/tech/lef \
                                  path/to/tech/captable"

set_db init_hdl_search_path      "$env(ROOT_DIR)/rtl"

set top                          "servant"

## Set design process node
set_db / .design_process_node {65}

## Set the target technology library

create_library_domain {masklib_dom}
set_db library_domain:masklib_dom     .library {tech.lib}

# replace `tech` by your tech lib name
get_db lib_cells -regexp ls_of_ld_masklib_dom/* -foreach {set_db $object .avoid true}
set_db lib_cell:ls_of_ld_masklib_dom/tech/INVD0   .avoid false
set_db lib_cell:ls_of_ld_masklib_dom/tech/AN2D0   .avoid false
set_db lib_cell:ls_of_ld_masklib_dom/tech/OR2D0   .avoid false
set_db lib_cell:ls_of_ld_masklib_dom/tech/XOR2D0  .avoid false
set_db lib_cell:ls_of_ld_masklib_dom/tech/DFCNQD1 .avoid false

set_db / .lef_library    {tech.lef}
set_db / .cap_table_file {tech.captable}

## Disables clock gating insertion
set_db / .lp_insert_clock_gating {false}

## Preserve hierarchies
set_db / .auto_ungroup {none}

## Read RTL and elaborate
read_hdl ../../../rtl/serv.v
read_hdl ../../../rtl/servant.v
read_hdl ../gates_cmo.v

elaborate

## Sets current design to top
current_design $top

## Synthesize the design
syn_generic
syn_map

write_hdl > netlist_unmasked.v

source ../masking_cmo.tcl

create_shared_top_ports $top
create_shared_hier_ports

set nregister [count_registers]
if {$nregister == 0} {
    puts "No registers found"
    suspend
}

set left_bit [expr $nregister - 1]
create_port_bus -left_bit $left_bit -right_bit 0 -name randbits -input $top
create_hport_everywhere "randbits" $left_bit
replace_cells_with_secure "CMO"

uniquify $top -verbose

connect_shared_wires $top "CMO"
connect_random_bus $nregister "CMO"

## generate verilog headers
write_synth_defines_vh  "CMO" $nregister "-1"
write_synth_defines_tcl "CMO" $nregister "-1"

## Save some reports
report_area  $top > area.rpt
report_gates $top > gates.rpt

## Write output files
write_hdl $top > netlist.v

