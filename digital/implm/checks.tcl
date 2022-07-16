proc report_dangling_nets {} {
    set fp [open "dangling_nets.rpt" "w"]
    set dangling_nets [get_db [get_db hnets -if {.num_loads  == 0}] .name]
    foreach net $dangling_nets {
        puts $fp $net
    }
    close $fp
}
 
proc dangling_input_pins {} {
    set fp [open "dangling_input_pins.rpt" "w"]
    set dangling_input_pins [get_db [get_db pins -if {.net.name == "" && .direction == in}] .name]
    foreach pin $dangling_input_pins {
          puts $fp $pin
    }
    set noDriver_input_pins [get_db [get_db pins -if {.net.num_drivers==0 && .direction == in && !.net.is_power && !.net.is_ground}] .name]
    foreach pin $noDriver_input_pins {
          puts $fp $pin
    }
    close $fp
}
 
proc dangling_out_pins {} {
    set fp [open "dangling_out_pins.rpt" "w"]
    set dangling_out_pins [get_db [get_db pins -if {.net.name == "" && .direction == out}] .name]
    foreach pin $dangling_out_pins {
          puts $fp $pin
    }
    set noLoad_out_pins [get_db [get_db pins -if {.net.num_loads==0 && .direction == out && !.net.is_power && !.net.is_ground}] .name]
    foreach pin $noLoad_out_pins {
          puts $fp $pin
    }
    close $fp
}
 
proc floating_instances {} {
    set fp [open "floating_instances.rpt" "w"]
    foreach inst [get_db insts .name] {  
        foreach pin [get_db inst:$inst .pins.name] { 
            if {[get_db pin:$pin -if {.direction=="in" && .net.name != "" && .net.num_drivers==0 && !.net.is_power && !.net.is_ground}] != ""} {
                puts $fp "Instance $inst : $pin"
            }
            if {[get_db pin:$pin -if {.direction=="out" && .net.name != "" && .net.num_loads==0 && !.net.is_power && !.net.is_ground}] != ""} {
                puts  $fp "Instance $inst : $pin"
            }
        }
    }
    close $fp
}

proc noclock_waveform {} {
    set fp [open "noclock_waveform.rpt" "w"]
    set pins [get_db pins -if { .is_clock == "true" && .cts_clock_tree == "" }]
    foreach pin $pins {
        puts $fp "$pin"
    }
    close $fp
}
 
proc floating_io_ports {} {
    set fp [open "floating_io_ports.rpt" "w"] 
    set in [get_db [get_db ports -if {.direction == in && .net.num_loads == 0}] .name]
    set out [get_db [get_db ports -if {.direction == out && .net.num_drivers == 0}] .name]     
    puts $fp "# floating io ports : [expr [llength $in] + [llength $out]] \n"
    puts $fp "# input ports : [llength $in]\n"
    puts $fp $in
    puts $fp "\n"
    puts $fp "# output ports : [llength $out]\n"
    puts $fp $out 
    close $fp 
}
