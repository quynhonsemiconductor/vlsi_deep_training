# PrimeTime STA, adapted from the assistant's DM_STA/PT flow.
# Reads the DC-synthesised netlist + mapped SDC from build/dc/<block>/results/.
source -echo ./pt_config.tcl

proc pt_fail {message} { puts stderr "\nERROR: $message"; quit }

set PT_START_TIME [clock seconds]
foreach d [list $REPORT_DIR $LOG_DIR $OUTPUT_DIR] {
    if {[catch {file mkdir $d} err]} { pt_fail "Cannot create $d: $err" }
}
puts "================================================================"
puts " PrimeTime STA: $DESIGN_NAME"
puts " Started: [clock format $PT_START_TIME -format {%Y-%m-%d %H:%M:%S}]"
puts "================================================================"

set_app_var search_path [concat /tools/eda/synopsys/syn/W-2024.09-SP3/libraries/syn $LIBRARY_DIR]
set_app_var link_library "* dw_foundation.sldb $LINK_LIBRARIES"

if {![file isfile $NETLIST_FILE]} { pt_fail "Netlist not found: $NETLIST_FILE" }
if {![file isfile $SDC_FILE]} { pt_fail "SDC not found: $SDC_FILE" }

read_verilog $NETLIST_FILE
current_design $DESIGN_NAME
link

puts "Reading constraints: $SDC_FILE"
source $SDC_FILE

# reports
redirect -file ${REPORT_DIR}/timing_setup.rpt {
    report_timing -delay_type max -path_type full -max_paths $MAX_PATHS -nworst $NWORST_PATHS
}
redirect -file ${REPORT_DIR}/timing_hold.rpt {
    report_timing -delay_type min -path_type full -max_paths $MAX_PATHS -nworst $NWORST_PATHS
}
redirect -file ${REPORT_DIR}/check_timing.rpt { check_timing }
redirect -file ${REPORT_DIR}/qor.rpt { report_qor }

# unconstrained endpoints
redirect -file ${REPORT_DIR}/unconstrained.rpt {
    set unconstrained_endpoints [report_timing -to [all_outputs] -max_paths 1 -nworst 1]
}

puts "STA complete: [expr [clock seconds] - $PT_START_TIME] sec"
quit
