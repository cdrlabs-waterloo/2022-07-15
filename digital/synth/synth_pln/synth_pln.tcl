## Set some paths definitions
set_db init_lib_search_path      "path/to/tech/lib \
                                  path/to/tech/lef \
                                  path/to/tech/captable"

set_db init_hdl_search_path      "$env(ROOT_DIR)/rtl"

set top                          "servant"

## Set the target technology library
set_db / .library        {tech.lib}
set_db / .lef_library    {tech.lef}
set_db / .cap_table_file {tech.captable}

## Set design process node
set_db / .design_process_node {65}

## Disables clock gating insertion
set_db / .lp_insert_clock_gating {false}

## Preserve hierarchies
set_db / .auto_ungroup {none}

## Read RTL and elaborate
read_hdl ../../../rtl/serv.v
read_hdl ../../../rtl/servant.v

elaborate

## Sets current design to top
current_design $top

## Synthesize the design
syn_generic
syn_map

## Save some reports
report_area  $top > top-area.rpt
report_gates $top > top-gates.rpt

## Write output files
write_hdl $top > netlist.v

