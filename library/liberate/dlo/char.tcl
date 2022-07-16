## target process is set by environment variable (tt, ss, ff, sf, fs)
puts "----------------------------------------------------------------"
puts "Process: $env(PROCESS)"
puts "Temp:    $env(TEMP)"
puts "Supply:  $env(SUPPLY)"
puts "Corner:  $env(CORNER)"
puts "View:    $env(VIEW)"
puts "----------------------------------------------------------------"

set_var extsim_cmd_option      "+aps +spice -mt +liberate +rcopt=2"
set_var extsim_deck_header     "simulator lang=spectre\nOpt1 options reltol=1e-4 \nsimulator lang=spice"

set_var extsim_option          "redefinedparams=ignore hier_ambiguity=lower limit=delta "
set_var extsim_leakage_option  "redefinedparams=ignore hier_ambiguity=lower limit=delta "

#set_var cleanup_tmpdir 0
set_var extsim_save_failed {all}
set_var extsim_save_passed {all}

set_vdd -type primary VDD  $env(SUPPLY)
set_gnd -type primary VSS  0.0

set_var max_transition     0.5e-9

set_var constraint_info            2
set_var write_logic_function       0
set_var reset_negative_constraint  1

## delay characterization: index1=slew range (ns), index2=load range (pf)
define_template \
    -type delay \
    -index_1 {0.001 0.003 0.005 0.007 0.009 0.011 0.015 0.020 0.025 0.030 0.035 0.040 0.050 0.060 0.070 0.080 0.090 0.100 0.200 0.250 0.300 0.400 0.480} \
    -index_2 {0.00046 0.00112 0.00244 0.00509 0.01037 0.02094 0.04209 0.08418 0.1257 0.2525 0.3367} \
    delay_template_23x11

## delay characterization: index1=slew range (ns), index2=load range (pf)
define_template \
    -type power \
    -index_1 {0.001 0.003 0.005 0.007 0.009 0.011 0.015 0.020 0.025 0.030 0.035 0.040 0.050 0.060 0.070 0.080 0.090 0.100 0.200 0.250 0.300 0.400 0.480} \
    -index_2 {0.00046 0.00112 0.00244 0.00509 0.01037 0.02094 0.04209 0.08418 0.1257 0.2525 0.3367} \
    power_template_23x11

## timing constraint (setup, hold, removal, recovery): 
##    index1=slew range for data signal (ns), 
##    index2=slew range for reference signal (clock, rst, etc) (ns)
define_template \
    -type constraint \
    -index_1 {0.001 0.003 0.005 0.007 0.009 0.011 0.015 0.020 0.025 0.030 0.035 0.040 0.050 0.060 0.070 0.080 0.090 0.100 0.200 0.250 0.300 0.400 0.480} \
    -index_2 {0.001 0.003 0.005 0.007 0.009 0.011 0.015 0.020 0.025 0.030 0.035 0.040 0.050 0.060 0.070 0.080 0.090 0.100 0.200 0.250 0.300 0.400 0.480} \
    const_template

set ao_cells {
    AO_DLO_D0
    AO_DLO_D1
}

foreach cell $ao_cells {
    define_cell \
       -input { A1 A2 B1 B2 CP } \
       -output { Z1 Z2 } \
       -pinlist {A1 A2 B1 B2 CP Z1 Z2} \
       -delay delay_template_23x11 \
       -power power_template_23x11 \
       $cell

    # Note: precharge CP=0, evaluation CP=1

    ## Z1 = (A1 & B1)

    # A or B rises during evaluation, Z will rise
    define_arc -type combinational -pin {Z1} -related_pin {A1}  -when {(B1 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(X) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z1} -related_pin {B1}  -when {(A1 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(X) $env(SUPPLY)" $cell
     
    # CP falls, starting pre-charge, Z will fall
    define_arc -type combinational -pin {Z1} -related_pin {CP} -when {(A1 B1)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(X) 0.0" $cell

    # CP rises, starting evaluation, Z will rises
    define_arc -type combinational -pin {Z1} -related_pin {CP} -when {(A1 B1)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(X) $env(SUPPLY)" $cell

    ## Z2 = (A2 | B2)

    # (A|B) rises during evaluation, Z will rise
    define_arc -type combinational -pin {Z2} -related_pin {A2}  -when {(!B2 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z2} -related_pin {B2}  -when {(!A2 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell
     
    # CP falls, starting pre-charge, Z will fall 
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {(!A2  B2)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(Y) 0.0" $cell
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {( A2 !B2)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(Y) 0.0" $cell
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {( A2  B2)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(Y) 0.0" $cell

    # CP rises, starting evaluation, Z will rises
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {(!A2  B2)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {( A2 !B2)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {( A2  B2)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell

}

set xor_cells {
    XOR_DLO_D0
    XOR_DLO_D1
    XOR_DLO_D2
}

foreach cell $xor_cells {
    define_cell \
       -input { A1 A2 B1 B2 CP } \
       -output { Z1 Z2 } \
       -pinlist {A1 A2 B1 B2 CP Z1 Z2} \
       -delay delay_template_23x11 \
       -power power_template_23x11 \
       $cell

    # Note: precharge CP=0, evaluation CP=1

    ## Z1 = (A1 ^ B1)

    # A^B rises during evaluation, Z will rise
    define_arc -type combinational -pin {Z1} -related_pin {A1}  -when {(!B1 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(X) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z1} -related_pin {B1}  -when {(!A1 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(X) $env(SUPPLY)" $cell
     
    # CP falls, starting pre-charge, Z will fall
    define_arc -type combinational -pin {Z1} -related_pin {CP} -when {(A1 !B1)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(X) 0.0" $cell
    define_arc -type combinational -pin {Z1} -related_pin {CP} -when {(!A1 B1)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(X) 0.0" $cell

    # CP rises, starting evaluation, Z will rises
    define_arc -type combinational -pin {Z1} -related_pin {CP} -when {(A1 !B1)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(X) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z1} -related_pin {CP} -when {(!A1 B1)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(X) $env(SUPPLY)" $cell

    ## Z2 = (A2 xnor B2)

    # (A xnor B) rises during evaluation, Z will rise
    define_arc -type combinational -pin {Z2} -related_pin {A2}  -when {(B2 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z2} -related_pin {B2}  -when {(A2 CP)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell
     
    # CP falls, starting pre-charge, Z will fall 
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {(A2  B2)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(Y) 0.0" $cell
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {(!A2 !B2)} -pin_dir {F} -related_pin_dir {F} -extsim_deck_header ".nodeset V(Y) 0.0" $cell

    # CP rises, starting evaluation, Z will rises
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {(A2  B2)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell
    define_arc -type combinational -pin {Z2} -related_pin {CP} -when {(!A2 !B2)} -pin_dir {R} -related_pin_dir {R} -extsim_deck_header ".nodeset V(Y) $env(SUPPLY)" $cell

}

set_operating_condition -voltage $env(SUPPLY) -temp $env(TEMP)

set_var extsim_model_include "$env(ROOT_DIR)/library/liberate/dlo/models/models_$env(PROCESS)"

set cells [concat $ao_cells $xor_cells]
set spicefiles {}
foreach cell $cells { 
    lappend spicefiles ../../../netlist/dlo/$env(VIEW)/sp/${cell}.sp
}

read_spice -format spectre "../models/models_$env(PROCESS) ${spicefiles}"

char_library -extsim spectre -cells $cells -thread 10 -user_arcs_only

## applies a safety margin on the constraints
## negative constraints will be zeroed due to 'reset_negative_constraint'
set_constraint -margin 2e-12

write_ldb hgo_library_dlo.ldb
write_library -driver_waveform -user_data ../user_data.lib "hgo_library_dlo_$env(CORNER)"
write_verilog -no_edge hgo_library_dlo.v
write_verilog -no_edge -power_pin hgo_library_dlo_pwr.v

