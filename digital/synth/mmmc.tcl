## 
## Name  Supply  Process  Temp
##--------------------------------------------
## BC    1.1V    FF       0C
## TC    1.0V    TT       25C
## WC    0.9V    SS       0C
## 

create_library_set -name wcl_slow -timing { 
    tech_wc.lib
    hgo_library_dlo_wc.lib
    ram_wc.lib
    rf_wc.lib
}
create_library_set -name wcl_fast -timing { 
    tech_bc.lib
    hgo_library_dlo_bc.lib
    ram_bc.lib
    rf_bc.lib
}
create_library_set -name wcl_typical -timing { 
    tech_tc.lib
    hgo_library_dlo_tc.lib
    ram_tc.lib
    rf_tc.lib
}

create_opcond -name op_cond_wcl_slow    -process 1 -voltage 0.9 -temperature 0
create_opcond -name op_cond_wcl_fast    -process 1 -voltage 1.1 -temperature 0
create_opcond -name op_cond_wcl_typical -process 1 -voltage 1.0 -temperature 25

create_timing_condition -name timing_cond_wcl_slow    -opcond op_cond_wcl_slow    -library_sets { wcl_slow }
create_timing_condition -name timing_cond_wcl_fast    -opcond op_cond_wcl_fast    -library_sets { wcl_fast }
create_timing_condition -name timing_cond_wcl_typical -opcond op_cond_wcl_typical -library_sets { wcl_typical }

create_rc_corner -name rc_corner -cap_table {tech.captable}

create_delay_corner -name delay_corner_wcl_slow -early_timing_condition timing_cond_wcl_slow \
                    -late_timing_condition timing_cond_wcl_slow -early_rc_corner rc_corner \
                    -late_rc_corner rc_corner

create_delay_corner -name delay_corner_wcl_fast -early_timing_condition timing_cond_wcl_fast \
                    -late_timing_condition timing_cond_wcl_fast -early_rc_corner rc_corner \
                    -late_rc_corner rc_corner

create_delay_corner -name delay_corner_wcl_typical -early_timing_condition timing_cond_wcl_typical \
                    -late_timing_condition timing_cond_wcl_typical -early_rc_corner rc_corner \
                    -late_rc_corner rc_corner

update_delay_corner -name delay_corner_wcl_slow \
                    -early_timing_condition {timing_cond_wcl_slow PD_CORE@timing_cond_wcl_slow} \
                    -late_timing_condition {timing_cond_wcl_slow PD_CORE@timing_cond_wcl_slow}
      
update_delay_corner -name delay_corner_wcl_fast \
                    -early_timing_condition {timing_cond_wcl_fast PD_CORE@timing_cond_wcl_fast} \
                    -late_timing_condition {timing_cond_wcl_fast PD_CORE@timing_cond_wcl_fast}
      
update_delay_corner -name delay_corner_wcl_typical \
                    -early_timing_condition {timing_cond_wcl_typical PD_CORE@timing_cond_wcl_typical} \
                    -late_timing_condition {timing_cond_wcl_typical PD_CORE@timing_cond_wcl_typical}


create_constraint_mode -name functional_wcl_slow    -sdc_files { ../../constraints/fun.sdc }
create_constraint_mode -name functional_wcl_fast    -sdc_files { ../../constraints/fun.sdc }
create_constraint_mode -name functional_wcl_typical -sdc_files { ../../constraints/fun.sdc }

create_analysis_view -name view_functional_wcl_slow    -constraint_mode functional_wcl_slow    -delay_corner delay_corner_wcl_slow
create_analysis_view -name view_functional_wcl_fast    -constraint_mode functional_wcl_fast    -delay_corner delay_corner_wcl_fast
create_analysis_view -name view_functional_wcl_typical -constraint_mode functional_wcl_typical -delay_corner delay_corner_wcl_typical

set_analysis_view -setup { \
    view_functional_wcl_slow        \
    view_functional_wcl_fast        \
    view_functional_wcl_typical     \
}

