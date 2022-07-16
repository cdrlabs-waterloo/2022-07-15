proc report_instances {} {
    set insts [get_db insts]
    set fp [open "report_instances.rpt" "w"]
    foreach inst $insts {
        set base_cell [get_db $inst .base_cell]
        puts $fp "$base_cell $inst"
    }
    close $fp
}

report_instances
report_area > report_area.rpt
