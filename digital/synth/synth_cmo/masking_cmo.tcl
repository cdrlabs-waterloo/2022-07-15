set InstDepthCache(NULL) 0

proc is_skip_net {name} {
    if {$name == "clk" || $name == "rst_n"} {
        return 1
    }
    if {[regexp {^randbits\[\d+\]$} $name] == 1} {
        return 1
    }
    return 0
}

proc append_s1 {name} {
    regexp {([^\[]+)(.*)} $name matchVar grp1 grp2
    return "${grp1}_s1${grp2}"
}

proc trim_type {name} {
    return [lindex [split $name :] 1]
}

proc is_secure_gate {name suffix} {
    if { [string match "INV_${suffix}*"   $name] == 1 ||
         [string match "AN2_${suffix}*"   $name] == 1 ||
         [string match "OR2_${suffix}*"   $name] == 1 ||
         [string match "XOR2_${suffix}*"  $name] == 1 ||
         [string match "DFCNQ_${suffix}*" $name] == 1 } {
        return 1
    }
    return 0
}

proc find_inst_depth {inst} {
    puts "find_inst_depth called for: $inst"
    upvar #0 InstDepthCache cache
    if { [info exists cache($inst)] == 1 } {
        puts "    Depth (from cache): $cache($inst)"
        return $cache($inst)
    }
    puts "Looping through all instance pins to find depth"
    set depth 0
    set pins [get_db $inst .pins]
    set cell [get_db $inst .base_cell.base_name]
    foreach pin $pins {
        puts "    Looking at pin: $pin"
        set pin_dir       [get_db $pin .direction]
        if { $pin_dir == "out" } {
            puts "    Pin is output. Skiping."
            continue
        }
        set driver        [get_db $pin .net.driver]
        set driver_type   [get_db $pin .net.driver.obj_type]
        if { $driver_type == "port" } {
            puts "    Pin is a top level port."
            if { $depth < 1 } { set depth 1 }
            continue
        }
        set driver_inst   [get_db $driver .inst]
        set driver_cell   [get_db $driver_inst .base_cell.base_name]
        if { $driver_cell == "DFCNQD1" || $driver_type == "constant" } {
            puts "    Pin is driven by seq/constant: $driver_cell/$driver_type"
            if { $depth < 1 } { set depth 1 }
            continue
        } elseif { $driver_type == "pin" } {
            set d [find_inst_depth $driver_inst]
            puts "    Came back from recursion with depth: $d"
            if { $cell == "XOR2_DLO_D0" } {
                puts "    Incrementing depth at XOR cell."
                incr d
            }
            if { $depth < $d } { set depth $d }
            continue
        } elseif { $driver == "" } {
            puts "    Pin not connected: $pin"
            continue
        } else {
            puts "    Unknown driver type: $driver_type"
            suspend
        }
    }
    if { $depth == 0 } {
        puts "Unable to find depth for instance: $inst"
        suspend
    }
    puts "Depth: $depth"
    set cache($inst) $depth
    return $depth
}

proc write_inst_depths {} {
    puts "write_inst_depths was called"
    upvar #0 InstDepthCache cache
    set f [open "inst_depths.csv" w]
    puts "Looping through depth cache to write CSV file"
    foreach key [array names cache] {
        puts $f "$key,$cache($key)"
    }
    close $f
}

proc write_synth_defines_vh { suffix nregister max_depth } {
    set suffix_lower [string tolower $suffix]
    puts "Writing synth defines verilog header"
    set f [open "${suffix_lower}_synth_defines.vh" w]
    puts $f "`define ${suffix}_RANDBITS_LEN   $nregister"
    puts $f "`define ${suffix}_MAX_DEPTH      $max_depth"
    close $f
}

proc write_synth_defines_tcl { suffix nregister max_depth } {
    set suffix_lower [string tolower $suffix]
    puts "Writing synth defines verilog header"
    set f [open "${suffix_lower}_synth_defines.tcl" w]
    puts $f "set ${suffix}_RANDBITS_LEN   $nregister"
    puts $f "set ${suffix}_MAX_DEPTH      $max_depth"
    close $f
}

proc create_hport_everywhere { name left_bit } {
    puts "create_hport_everywhere was called"
    puts "Looping through all hinsts to create new hport"
    set hinsts [get_db hinsts ]
    foreach hinst $hinsts { 
        puts "    Hinstance: $hinst"
        puts "    Creating hport bus: $name\[$left_bit:0\]"
        create_hport_bus -left_bit $left_bit -right_bit 0 -name $name -input $hinst
    }
}

proc create_shared_top_ports {top} {
    puts "create_shared_top_ports was called"
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
            set shared_name [append_s1 $name]
            set left_bit [expr [llength [get_db $port_bus .bits] ] - 1 ]
            if {$left_bit > 0} {
                create_port_bus -left_bit $left_bit -right_bit 0 -name $shared_name $direction $top
            } else {
                create_port_bus -name $shared_name $direction $top
            }
        }
    }
}

proc create_shared_hier_ports {} {
    puts "create_shared_hier_ports was called"
    puts "Looping over hport_busses to create shared ports"
    set hport_busses [get_db hport_busses]
    foreach hport_bus $hport_busses { 
        set direction [get_db $hport_bus .direction]
        if {$direction == "out"} {
            set direction "-output"
        } else {
            set direction "-input"
        }
        set name [get_db $hport_bus .base_name]
        set hinst [get_db $hport_bus .hinst]
        if {[is_skip_net $name] == 0} {
            set shared_name [append_s1 $name]
            set left_bit [expr [llength [get_db $hport_bus .bits] ] - 1 ]
            if {$left_bit > 0} {
                create_hport_bus -left_bit $left_bit -right_bit 0 -name $shared_name $direction $hinst
            } else {
                create_hport_bus -name $shared_name $direction $hinst
            }
        }
    }
}

proc count_registers {} {
    puts "count_registers was called"
    return [llength [get_db insts -if {.is_flop == true}]]
}

proc replace_cells_with_secure {suffix} {
    puts "replace_cells_with_secure was called"

    set gates("base_cell:INVD0")    "design:INV_${suffix}"
    set pmaps("base_cell:INVD0")    {{I I_S0} {ZN ZN_S0}}

    set gates("base_cell:AN2D0")    "design:AN2_${suffix}"
    set pmaps("base_cell:AN2D0")    {{A1 A1_S0} {A2 A2_S0} {Z Z_S0}}

    set gates("base_cell:OR2D0")    "design:OR2_${suffix}"
    set pmaps("base_cell:OR2D0")    {{A1 A1_S0} {A2 A2_S0} {Z Z_S0}}

    set gates("base_cell:XOR2D0")   "design:XOR2_${suffix}"
    set pmaps("base_cell:XOR2D0")   {{A1 A1_S0} {A2 A2_S0} {Z Z_S0}}

    set gates("base_cell:DFCNQD1")  "design:DFCNQ_${suffix}"
    set pmaps("base_cell:DFCNQD1")  {{CP CP} {CDN CDN} {D D_S0} {Q Q_S0}}

    puts "Change instance links"
    foreach {gate gate_replace} [array get gates] {
        puts "Gate: $gate -> $gate_replace"
        get_db insts -if {.base_cell == $gate} -foreach {
            set inst $object
            set parent [get_db $inst .parent.module.base_name]
            if {[is_secure_gate $parent $suffix] == 1} {
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

proc connect_shared_wires {top suffix} {
    puts "connect_shared_wires was called"

    puts "Iterating over all hnets"
    set hnets [get_db hnets]
    foreach hnet $hnets {
        set hnet_share [append_s1 $hnet]

        set hnet_name        [get_db $hnet .base_name]
        set hnet_name_share  [append_s1 $hnet_name]
        set hnet_name_hinst  [get_db $hnet .hinst.module.base_name]

        if { [is_secure_gate $hnet_name_hinst $suffix] == 1 } {
            puts "    Skiped (base cell) hnet: $hnet_name"
            continue
        }

        if {[is_skip_net $hnet_name] == 1} {
            puts "    Skiped (clk/rst) hnet: $hnet_name"
            continue
        }

        puts "    Creating connections for hnet: $hnet"
        puts "    Hnet (share): $hnet_share"

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

            if { [is_secure_gate $hnet_load_hinst $suffix] == 1 } {
                set hnet_load_share       "[string trimright ${hnet_load} {_S0}]_S1"
            } else {
                set hnet_load_share       [append_s1 $hnet_load]
            }

            if { [is_secure_gate $hnet_driver_hinst $suffix] == 1 } {
                set hnet_driver_share       "[string trimright ${hnet_driver} {_S0}]_S1"
            } else {
                if { $hnet_driver_type == "constant" } {
                    set old                     [get_db $hnet_driver .base_name]
                    set new                     [expr $old == "1" ? "0" : "1"]
                    set hnet_driver_share       [regsub "${old}\$" $hnet_driver $new]
                } else {
                    set hnet_driver_share       [append_s1 $hnet_driver]
                }
            }

            puts "        Hnet load share:   $hnet_load_share"
            puts "        Hnet driver share: $hnet_driver_share"

            set connect "connect -net_name $hnet_name_share $hnet_driver_share $hnet_load_share"
            puts "        Connecting: $connect"
            eval $connect
        }
    }
}

proc connect_random_bus {nregister suffix} {
    puts "connect_random_bus was called"
    set i 0
    foreach hinst [get_db hinsts] {
        set module_name [get_db $hinst .module.base_name]
        if { [string match "DFCNQ_${suffix}*" $module_name] == 1 } {
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
    upvar #0 InstDepthCache cache
    puts "connect_precharge_clock was called"

    puts "Intermidiate connections of precharge clock"
    set hports [get_db hports -if { .base_name == clk_precharge[*] }]
    foreach hport $hports {
        set parent  [get_db $hport .hinst.parent]
        set busat   [get_db $hport .base_name]
        set driver  [trim_type $parent]/$busat
        set connect "connect -net_name $busat $driver $hport"
        puts "    Connecting: $connect"
        eval $connect
    }

    puts "Connecting the precharge clock to the domino gates"
    set insts [get_db insts -if {(.base_cell.name == XOR2_DLO_D0) || (.base_cell.name == AN2_DLO_D0) || (.base_cell.name == OR2_DLO_D0)} ]
    foreach inst $insts {
        set i [expr $cache($inst) - 1]
        set driver  "[trim_type [get_db $inst .parent]]/clk_precharge\[$i\]"
        set load    "[trim_type $inst]/CP"
        set connect "connect -net_name clk_precharge\[$i\] $driver $load"
        puts "    Connecting: $connect"
        eval $connect
    }
}

proc find_max_depth {} {
    puts "Loading depth cache and search for maximum depth"
    set insts [get_db insts -if {(.base_cell.name == XOR2_DLO_D0) || (.base_cell.name == AN2_DLO_D0) || (.base_cell.name == OR2_DLO_D0)} ]
    set max_depth 0
    foreach inst $insts {
        set depth [find_inst_depth $inst]
        if { $max_depth < $depth } {
            set max_depth $depth
        }
    }
    puts "Maximum depth found: $max_depth"

    write_inst_depths

    if { $max_depth == 0 } {
        puts "Invalid maximum depth: $max_depth"
        suspend
    }
    return $max_depth
}

proc resize_domino_cells {} {
    puts "Resizing domino logic gates according to wire capacitance"
    set insts [get_db insts -if {(.base_cell.name == XOR2_DLO_D0)}]

    foreach inst $insts {
        set pin_z     "pin:[trim_type $inst]/Z"
        set cap_z     [get_db $pin_z .wire_capacitance]
        set new_cell  ""

        if { $cap_z > 30 } {
            set new_cell "XOR2_DLO_D2"
        } elseif { $cap_z > 10 } {
            set new_cell "XOR2_DLO_D1"
        }
        if { $new_cell != "" } {
            puts "    Resize inst to cell $new_cell with cap=$cap_z fF: $inst"
            change_link -instances $inst \
                        -lib_cell $new_cell \
                        -pin_map {{A A} {B B} {CP CP} {Z Z}}
        }
    }
}
