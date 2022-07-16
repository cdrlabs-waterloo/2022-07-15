## ram instances were removed from RTL, instantiate your macro
set inst_ram                     "inst:hgo_top/U_SERVANT_TOP/U_RAM/U_RAM"
set inst_rf                      "inst:hgo_top/U_SERVANT_TOP/U_RF/U_RF"

## performs floorplanning
create_floorplan -site core -core_size 600 600 20 20 20 20

## spreads out the block pins only along the left edge
edit_pin -snap mgrid \
         -fix_overlap 1 \
         -spacing 10 \
         -spread_direction clockwise \
         -side Left \
         -layer 3 \
         -spread_type center \
         -pin {HGO_TCK HGO_TMS HGO_TDI HGO_TDO HGO_RSTN HGO_Q0 HGO_Q1}

## Careful, always put it on grid!
set RAM_xy            {442   398}
set RF_xy             {20    515}

set CORE_bl {0}
set CORE_tr {1000}

## place the block cells
place_inst $inst_ram             $RAM_xy
place_inst $inst_rf              $RF_xy

## create placement halos (left bottom right top)
create_place_halo -halo_deltas {14 14  0  0} -cell artisan_ram
create_place_halo -halo_deltas { 0 14 14  0} -cell artisan_rf

## delete and recreate all rows
split_row -site gacore    -area $CORE_bl $CORE_bl $CORE_tr $CORE_tr
split_row -site dcore     -area $CORE_bl $CORE_bl $CORE_tr $CORE_tr
split_row -site ccore     -area $CORE_bl $CORE_bl $CORE_tr $CORE_tr
split_row -site bcoreExt  -area $CORE_bl $CORE_bl $CORE_tr $CORE_tr
split_row -site bcore     -area $CORE_bl $CORE_bl $CORE_tr $CORE_tr

deselect_obj -all
select_obj [get_db $inst_ram]
split_row -selected

deselect_obj -all
select_obj [get_db $inst_rf]
split_row -selected

## Save database with floorplanning
write_db fpdone-db
