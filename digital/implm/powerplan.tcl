## configuration of rings and vias
set_db add_rings_target                             default
set_db add_rings_extend_over_row                    0
set_db add_rings_ignore_rows                        0
set_db add_rings_avoid_short                        0
set_db add_rings_skip_shared_inner_ring             none
set_db add_rings_stacked_via_top_layer              AP
set_db add_rings_stacked_via_bottom_layer           M1
set_db add_rings_via_using_exact_crossover_size     1
set_db add_rings_orthogonal_only                    true
set_db add_rings_skip_via_on_pin                    { standardcell }
set_db add_rings_skip_via_on_wire_shape             { noshape }

set_db generate_special_via_symmetrical_via_only    {true}
set_db generate_special_via_snap_via_center_to_grid {M1 either M2 either M3 either M4 either M5 either M6 either M7 either}

##
## rings and strips should use multiples of row height to avoid DRC problems
##

## Core
add_rings \
          -nets {VSS VDD} \
          -type core_rings \
          -follow core \
          -layer {top M1 bottom M1 left M2 right M2} \
          -width {top 5.4 bottom 5.4 left 5.4 right 5.4} \
          -spacing {top 1.8 bottom 1.8 left 1.8 right 1.8} \
          -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} \
          -center 0 \
          -extend_corners {} \
          -threshold 0 \
          -jog_distance 0 \
          -snap_wire_center_to_grid either

## RAM
deselect_obj -all
select_obj [get_db $inst_ram]

add_rings \
        -nets {VSS VDD} \
        -type block_rings \
        -around selected \
        -layer {top M1 bottom M1 left M2 right M2} \
        -width {top 3.6 bottom 3.6 left 3.6 right 3.6} \
        -spacing {top 1.8 bottom 1.8 left 1.8 right 1.8} \
        -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} \
        -threshold 100 \
        -snap_wire_center_to_grid either

## RF
deselect_obj -all
select_obj [get_db $inst_rf]

add_rings \
        -nets {VSS VDD} \
        -type block_rings \
        -around selected \
        -layer {top M1 bottom M1 left M2 right M2} \
        -width {top 3.6 bottom 3.6 left 3.6 right 3.6} \
        -spacing {top 1.8 bottom 1.8 left 1.8 right 1.8} \
        -offset {top 1.8 bottom 1.8 left 1.8 right 1.8} \
        -threshold 100 \
        -snap_wire_center_to_grid either

##
## Create stripes over the SRAMs in M5
##

deselect_obj -all
select_obj [get_db $inst_rf]

add_stripes \
    -nets {VDD VSS} \
    -direction vertical \
    -layer M5 \
    -width 3.6 \
    -set_to_set_distance 25 \
    -start_from left \
    -start_offset 5 \
    -stop_offset 0 \
    -spacing 2 \
    -over_power_domain 1

deselect_obj -all
select_obj [get_db $inst_ram]

add_stripes \
    -nets {VDD VSS} \
    -direction vertical \
    -layer M5 \
    -width 3.6 \
    -set_to_set_distance 25 \
    -start_from left \
    -start_offset 9 \
    -stop_offset 0 \
    -spacing 2 \
    -over_power_domain 1

##
## Core power stripes in M8 (vertical) and M9 (horizontal)
##

deselect_obj -all

set_db add_stripes_route_over_rows_only {true}

add_stripes \
    -nets {VDD VSS} \
    -direction vertical \
    -layer M8 \
    -width 3.6 \
    -set_to_set_distance 35 \
    -start_from left \
    -start_offset 13 \
    -stop_offset 0 \
    -spacing 2

add_stripes \
    -nets {VDD VSS} \
    -direction horizontal \
    -layer M9 \
    -width 3.6 \
    -set_to_set_distance 30 \
    -start_from bottom \
    -start_offset 13 \
    -stop_offset 0 \
    -spacing 2

##
## Routing power stripes
##

route_special \
    -nets {VDD VSS} \
    -connect {block_pin pad_pin core_pin floating_stripe} \
    -layer_change_range {M1(1) M9(9)} \
    -block_pin_target {nearest_target} \
    -pad_pin_port_connect {all_port all_geom} \
    -pad_pin_target {nearest_target} \
    -core_pin_target {first_after_row_end} \
    -floating_stripe_target {block_ring ring stripe ring_pin block_pin followpin} \
    -allow_jogging 0 \
    -crossover_via_layer_range { M1(1) M9(9) } \
    -allow_layer_change 1 \
    -block_pin use_lef \
    -pad_pin_layer_range { M1(1) M9(9) } \
    -target_via_layer_range { M1(1) M9(9) }

check_drc

## reduces the size of vias to avoids via enclosure error on M8/M9
update_power_vias -via_scale_width  85 -update_vias 1 -bottom_layer M8 -top_layer M9
update_power_vias -via_scale_height 85 -update_vias 1 -bottom_layer M8 -top_layer M9

update_power_vias -via_scale_width  85 -update_vias 1 -bottom_layer M7 -top_layer M8
update_power_vias -via_scale_height 85 -update_vias 1 -bottom_layer M7 -top_layer M8

## Save database with power grid
write_db pgdone-db
    
