proc is_skip_net {name} {
    if {$name == "clk" || $name == "rst_n"} {
        return 1
    }
    if {[regexp {^randbits\[\d+\]$} $name] == 1} {
        return 1
    }
    return 0
}

proc append_s {name} {
    regexp {([^\[]+)(.*)} $name matchVar grp1 grp2
    return "${grp1}_s1${grp2}"
}

proc append_n {name} {
    regexp {([^\[]+)(.*)} $name matchVar grp1 grp2
    return "${grp1}_not${grp2}"
}

proc trim_type {name} {
    return [lindex [split $name :] 1]
}

proc is_secure_gate {name} {
    set secure_gates {
        "AN_XYZ_DLO"
        "OR_XYZ_DLO"
        "INV_XYZ_DLO"
        "XOR_SHR_DLO"
        "INV_SHR_DLO"
        "AN_SHR_DLO"
        "OR_SHR_DLO"
        "REG_SHR_DLO"
    }
    foreach gate $secure_gates {
        if { [string match "${gate}*"  $name] == 1 } {
            return 1
        }
    }
    return 0
}

proc write_synth_defines_vh { nregister } {
    puts "Writing synth defines verilog header"
    set f [open "dlo_synth_defines.vh" w]
    puts $f "`define DLO_RANDBITS_LEN   $nregister"
    close $f
}

proc write_synth_defines_tcl { nregister } {
    puts "Writing synth defines verilog header"
    set f [open "dlo_synth_defines.tcl" w]
    puts $f "set DLO_RANDBITS_LEN   $nregister"
    close $f
}

proc check_hport_bus_exists {hinst busname} {
    set hport_busses [get_db $hinst .hport_busses]
    foreach hport_bus $hport_busses {
        set name [get_db $hport_bus .base_name]
        if { $name == $busname } {
            return 1
        }
    }
    return 0
}

proc create_hport_everywhere { name left_bit } {
    puts "Looping through all hinsts to create new hport"
    set hinsts [get_db hinsts]
    foreach hinst $hinsts { 
        puts "    Hinstance: $hinst"
        puts "    Creating hport bus: $name\[$left_bit:0\]"
        if { [check_hport_bus_exists $hinst $name] == 0 } {
            if { $left_bit > 0 } {
                create_hport_bus -left_bit $left_bit -right_bit 0 -name $name -input $hinst
            } else {
                create_hport_bus -name $name -input $hinst
            }
        }
    }
}

proc create_shared_and_not_top_ports {top} {
    puts "Looping to port_busses to create shared and not ports"
    set port_busses [get_db port_busses]
    foreach port_bus $port_busses { 
        set direction [get_db $port_bus .direction]
        if {$direction == "out"} {
            set direction "-output"
        } else {
            set direction "-input"
        }
        set name [get_db $port_bus .base_name]
        if {[is_skip_net $name] == 0} {
            set name_n   [append_n $name]
            set name_s   [append_s $name]
            set name_s_n [append_n $name_s]
            set left_bit [expr [llength [get_db $port_bus .bits] ] - 1 ]
            if {$left_bit > 0} {
                create_port_bus -left_bit $left_bit -right_bit 0 -name $name_n   $direction $top
                create_port_bus -left_bit $left_bit -right_bit 0 -name $name_s   $direction $top
                create_port_bus -left_bit $left_bit -right_bit 0 -name $name_s_n $direction $top
            } else {
                create_port_bus -name $name_n   $direction $top
                create_port_bus -name $name_s   $direction $top
                create_port_bus -name $name_s_n $direction $top
            }
        }
    }
}

proc create_shared_and_not_hier_ports {} {
    puts "Looping over hport_busses to create shared and not ports"
    set hport_busses [get_db hport_busses]
    foreach hport_bus $hport_busses { 
        set direction [get_db $hport_bus .direction]
        if {$direction == "out"} {
            set direction "-output"
        } else {
            set direction "-input"
        }
        set name  [get_db $hport_bus  .base_name]
        set hinst [get_db $hport_bus .hinst]
        if {[is_skip_net $name] == 0} {
            set name_n   [append_n $name]
            set name_s   [append_s $name]
            set name_s_n [append_n $name_s]
            set left_bit [expr [llength [get_db $hport_bus .bits] ] - 1 ]
            if {$left_bit > 0} {
                create_hport_bus -left_bit $left_bit -right_bit 0 -name $name_n   $direction $hinst
                create_hport_bus -left_bit $left_bit -right_bit 0 -name $name_s   $direction $hinst
                create_hport_bus -left_bit $left_bit -right_bit 0 -name $name_s_n $direction $hinst
            } else {
                create_hport_bus -name $name_n   $direction $hinst
                create_hport_bus -name $name_s   $direction $hinst
                create_hport_bus -name $name_s_n $direction $hinst
            }
        }
    }
}

proc count_registers {} {
    puts "count_registers was called"
    return [llength [get_db insts -if {.is_flop == true}]]
}

proc replace_cells_with_secure {} {
    puts "replace_cells_with_secure was called"

    set gates("base_cell:INVD0")    "design:INV_SHR_DLO"
    set pmaps("base_cell:INVD0")    {{I I_S0} {ZN ZN_S0}}

    set gates("base_cell:AN2D0")    "design:AN_SHR_DLO"
    set pmaps("base_cell:AN2D0")    {{A1 A1_S0} {A2 A2_S0} {Z Z_S0}}

    set gates("base_cell:OR2D0")    "design:OR_SHR_DLO"
    set pmaps("base_cell:OR2D0")    {{A1 A1_S0} {A2 A2_S0} {Z Z_S0}}

    set gates("base_cell:XOR2D0")   "design:XOR_SHR_DLO"
    set pmaps("base_cell:XOR2D0")   {{A1 A1_S0} {A2 A2_S0} {Z Z_S0}}

    set gates("base_cell:DFCNQD1")  "design:REG_SHR_DLO"
    set pmaps("base_cell:DFCNQD1")  {{CP CP} {CDN CDN} {D D_S0} {Q Q_S0}}

    puts "Change instance links"
    foreach {gate gate_replace} [array get gates] {
        puts "Gate: $gate -> $gate_replace"
        get_db insts -if {.base_cell == $gate} -foreach {
            set inst $object
            set parent [get_db $inst .parent.module.base_name]
            if {[is_secure_gate $parent] == 1} {
                puts "    Skiped inst: $inst ($parent)"
                continue
            }
            puts "    Masking: $inst ($gate)"
            change_link -instances $inst \
                        -design_name $gate_replace \
                        -change_in_non_uniq_subdesign \
                        -lenient \
                        -pin_map $pmaps($gate)
        }
    }
}

proc connect_shared_and_not_wires {top} {
    puts "Connecting shared and not wires"

    puts "Iterating over all hnets"
    set hnets [get_db hnets]
    foreach hnet $hnets {
        set hnet_name        [get_db $hnet .base_name]
        set hnet_name_n      [append_n $hnet_name]
        set hnet_name_s      [append_s $hnet_name]
        set hnet_name_s_n    [append_n $hnet_name_s]
        set hnet_name_hinst  [get_db $hnet .hinst.module.base_name]

        if { [is_secure_gate $hnet_name_hinst] == 1 } {
            puts "    Skiped (base cell) hnet: $hnet_name"
            continue
        }

        if {[is_skip_net $hnet_name] == 1} {
            puts "    Skiped (clk/rst) hnet: $hnet_name"
            continue
        }

        puts "    Creating connections for hnet: $hnet"
        puts "    Hnet (not):       $hnet_name_n"
        puts "    Hnet (share):     $hnet_name_s"
        puts "    Hnet (share not): $hnet_name_s_n"

        puts "    Looping over hnet loads"
        set hnet_loads [get_db $hnet .loads]
        foreach hnet_load $hnet_loads {
            if { [get_object_type $hnet_load] == "port" } {
                set hnet_load_hinst     "$top"
            } else {
                set hnet_load_hinst     [get_db $hnet_load .hinst.module.base_name]
            }

            set hnet_driver           [lindex [get_db $hnet .drivers] 0]
            if { [get_object_type $hnet_driver] == "port" } {
                set hnet_driver_hinst     "$top"
            } else {
                set hnet_driver_hinst     [get_db $hnet_driver .hinst.module.base_name]
                set hnet_driver_type      [get_db $hnet_driver .obj_type]
            }

            puts "        Hnet load:         $hnet_load"
            puts "        Hnet load hinst:   $hnet_load_hinst"
            puts "        Hnet driver:       $hnet_driver"
            puts "        Hnet driver hinst: $hnet_driver_hinst"
            puts "        Hnet driver type:  $hnet_driver_type"

            if { [is_secure_gate $hnet_load_hinst] == 1 } {
                set hnet_load_n       "[string trimright ${hnet_load} {_S0}]_S0N"
                set hnet_load_s       "[string trimright ${hnet_load} {_S0}]_S1"
                set hnet_load_s_n     "[string trimright ${hnet_load} {_S0}]_S1N"
            } else {
                set hnet_load_n        [append_n $hnet_load]
                set hnet_load_s        [append_s $hnet_load]
                set hnet_load_s_n      [append_n $hnet_load_s]
            }

            if { [is_secure_gate $hnet_driver_hinst] == 1 } {
                set hnet_driver_n         "[string trimright ${hnet_driver} {_S0}]_S0N"
                set hnet_driver_s         "[string trimright ${hnet_driver} {_S0}]_S1"
                set hnet_driver_s_n       "[string trimright ${hnet_driver} {_S0}]_S1N"
            } else {
                if { $hnet_driver_type == "constant" } {
                    set old                 [get_db $hnet_driver .base_name]
                    set new                 [expr $old == "1" ? "0" : "1"]
                    set inverted            [regsub "${old}\$" $hnet_driver $new]
                    set hnet_driver_n       $inverted
                    set hnet_driver_s       $inverted
                    set hnet_driver_s_n     $hnet_driver
                } else {
                    set hnet_driver_n       [append_n $hnet_driver]
                    set hnet_driver_s       [append_s $hnet_driver]
                    set hnet_driver_s_n     [append_n $hnet_driver_s]
                }
            }

            puts "        Hnet load not:         $hnet_load_n"
            puts "        Hnet load share:       $hnet_load_s"
            puts "        Hnet load share not:   $hnet_load_s_n"
            puts "        Hnet driver not:       $hnet_driver_n"
            puts "        Hnet driver share:     $hnet_driver_s"
            puts "        Hnet driver share not: $hnet_driver_s_n"

            set connect_n   "connect -net_name $hnet_name_n   $hnet_driver_n   $hnet_load_n"
            set connect_s   "connect -net_name $hnet_name_s   $hnet_driver_s   $hnet_load_s"
            set connect_s_n "connect -net_name $hnet_name_s_n $hnet_driver_s_n $hnet_load_s_n"
            puts "        Connecting (n):   $connect_n"
            puts "        Connecting (s):   $connect_s"
            puts "        Connecting (s n): $connect_s_n"
            eval $connect_n
            eval $connect_s
            eval $connect_s_n
        }
    }
}

proc connect_random_bus {nregister} {
    puts "Connecting random buses"
    set i 0
    foreach hinst [get_db hinsts] {
        set module_name [get_db $hinst .module.base_name]
        if { [string match "REG_SHR_DLO*" $module_name] == 1 } {
            set busat   "randbits\[$i\]"
            set driver  [trim_type [get_db $hinst .parent]]/$busat
            set load    [trim_type $hinst]/R
            set connect "connect -net_name $busat $driver $load"
            puts "    Connecting: $connect"
            eval $connect
            incr i
        }
    }

    puts "Intermidiate connections of random bus"
    set hports [get_db hports -if { .base_name == randbits[*] }]
    foreach hport $hports {
        set parent  [get_db $hport .hinst.parent]
        set busat   [get_db $hport .base_name]
        set driver  [trim_type $parent]/$busat
        set connect "connect -net_name $busat $driver $hport"
        puts "    Connecting: $connect"
        eval $connect
    }
}

proc connect_precharge_clock {} {
    puts "Intermidiate connections of precharge clock"
    set hports [get_db hports -if { .base_name == clk_pch }]
    foreach hport $hports {
        set parent  [get_db $hport .hinst.parent]
        set driver  "[trim_type $parent]/clk_pch"
        set connect "connect -net_name clk_pch $driver $hport"
        puts "    Connecting: $connect"
        eval $connect
    }

    puts "Connect precharge clock to the secure gates"
    foreach hinst [get_db hinsts] {
        set module_name [get_db $hinst .module.base_name]
        if { [is_secure_gate $module_name] == 1 } {
            if { [check_hport_bus_exists $hinst "CP"] == 1 } {
                set hport_cp     "hport:[trim_type $hinst]/CP"
                set hport_driver [get_db $hport_cp .net.driver]
                if { $hport_driver == "" } {
                    set driver  "[trim_type [get_db $hinst .parent]]/clk_pch"
                    set load    "[trim_type $hinst]/CP"
                    set connect "connect -net_name clk_pch $driver $load"
                    puts "    Connecting: $connect"
                    eval $connect
                }
            }
        }
    }
}

proc resize_ao_domino_cells {} {
    puts "Resizing domino logic gates according to wire capacitance"
    set insts [get_db insts -if {(.base_cell.name == AO_DLO_D0)}]

    foreach inst $insts {
        set pin_z1    "pin:[trim_type $inst]/Z1"
        set pin_z2    "pin:[trim_type $inst]/Z2"
        set cap_z1    [get_db $pin_z1 .wire_capacitance]
        set cap_z2    [get_db $pin_z2 .wire_capacitance]
        set cap       [expr max($cap_z1, $cap_z2)]
        set new_cell  ""

        if { $cap > 20 } {
            set new_cell "AO_DLO_D1"
        }
        if { $new_cell != "" } {
            puts "    Resize inst to cell $new_cell with cap=$cap fF: $inst"
            change_link -instances $inst \
                        -lib_cell $new_cell \
                        -pin_map {{A1 A1} {A2 A2} {B1 B1} {B2 B2} {CP CP} {Z1 Z1} {Z2 Z2}}
        }
    }
}

proc resize_xor_domino_cells {} {
    puts "Resizing domino logic gates according to wire capacitance"
    set insts [get_db insts -if {(.base_cell.name == XOR_DLO_D0)}]

    foreach inst $insts {
        set pin_z1    "pin:[trim_type $inst]/Z1"
        set pin_z2    "pin:[trim_type $inst]/Z2"
        set cap_z1    [get_db $pin_z1 .wire_capacitance]
        set cap_z2    [get_db $pin_z2 .wire_capacitance]
        set cap       [expr max($cap_z1, $cap_z2)]
        set new_cell  ""

        if { $cap > 40 } {
            set new_cell "XOR_DLO_D2"
        } elseif { $cap > 20 } {
            set new_cell "XOR_DLO_D1"
        }
        if { $new_cell != "" } {
            puts "    Resize inst to cell $new_cell with cap=$cap fF: $inst"
            change_link -instances $inst \
                        -lib_cell $new_cell \
                        -pin_map {{A1 A1} {A2 A2} {B1 B1} {B2 B2} {CP CP} {Z1 Z1} {Z2 Z2}}
        }
    }
}

proc resize_registers {} {
    puts "Resizing registers according to wire capacitance"
    set insts [get_db insts -if {(.base_cell.name == DFCND1)}]

    foreach inst $insts {
        set pin_q     "pin:[trim_type $inst]/Q"
        set pin_qn    "pin:[trim_type $inst]/QN"
        set cap_q     [get_db $pin_q  .wire_capacitance]
        set cap_qn    [get_db $pin_qn .wire_capacitance]
        set cap       [expr max($cap_q, $cap_qn)]
        set new_cell  ""

        if { $cap > 40 } {
            set new_cell "DFCND4"
        } elseif { $cap > 20 } {
            set new_cell "DFCND2"
        }
        if { $new_cell != "" } {
            puts "    Resize inst to cell $new_cell with cap=$cap fF: $inst"
            change_link -instances $inst \
                        -lib_cell $new_cell \
                        -pin_map {{D D} {CP CP} {Q Q} {QN QN} {CDN CDN}}
        }
    }
}
