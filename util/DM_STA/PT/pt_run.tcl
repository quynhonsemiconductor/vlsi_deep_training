########################################################################
# pt_run.tcl
# Batch STA flow for Synopsys PrimeTime.
########################################################################

foreach name [array names env] {
	set "$name" "$env($name)"
}

source -echo -verbose ./pt_config.tcl

proc pt_fail {message} {
    puts stderr "\nERROR: $message"
    quit
}

proc pt_report {path command} {
    global MAX_PATHS
    global NWORST_PATHS 
    redirect -file $path $command
}

set PT_START_TIME [clock seconds]
foreach directory [list $REPORT_DIR $LOG_DIR $OUTPUT_DIR] {
    if {[catch {file mkdir $directory} err]} {
        pt_fail "Cannot create $directory: $err"
    }
}

puts "================================================================"
puts " PrimeTime static timing analysis: $DESIGN_NAME"
puts " Started: [clock format $PT_START_TIME -format {%Y-%m-%d %H:%M:%S}]"
puts "================================================================"

#-----------------------------------------------------------------------
# Library and tool setup
#-----------------------------------------------------------------------
if {[llength $LINK_LIBRARIES] == 0} {
    pt_fail "LINK_LIBRARIES is empty. Set the timing .db libraries in pt_config.tcl."
}

set_app_var search_path [concat /tools/eda/synopsys/syn/W-2024.09-SP3/libraries/syn $LIBRARY_DIR]
set_app_var link_library "* dw_foundation.sldb $LINK_LIBRARIES"

foreach app_var_entry $APP_VARS {
    if {[llength $app_var_entry] != 2} {
        pt_fail "Each APP_VARS entry must use format {name value}: $app_var_entry"
    }

    lassign $app_var_entry app_var_name app_var_value
    puts "Application variable: $app_var_name = $app_var_value"
    if {[catch {set_app_var $app_var_name $app_var_value} err]} {
        pt_fail "Cannot set application variable '$app_var_name': $err"
    }
}
foreach message_id $MESSAGE_FOR_SUPPRESS {
    suppress_message $message_id
}

#-----------------------------------------------------------------------
# Read mapped netlist, optional power intent, and synthesis constraints.
#-----------------------------------------------------------------------
if {![file isfile $NETLIST_FILE]} {
    pt_fail "Mapped netlist not found: $NETLIST_FILE"
}
if {![file isfile $SDC_FILE]} {
    pt_fail "Synthesis output SDC not found: $SDC_FILE"
}

puts "Read netlist: $NETLIST_FILE"
if {[catch {read_verilog $NETLIST_FILE} err]} {
    pt_fail "read_verilog failed: $err"
}
if {[catch {link_design $DESIGN_NAME} err]} {
    pt_fail "link_design failed: $err"
}
current_design $DESIGN_NAME

puts "Read SDC: $SDC_FILE"
if {[catch {read_sdc $SDC_FILE} err]} {
    pt_fail "read_sdc failed: $err"
}

#-----------------------------------------------------------------------
# Timing update and design checks
#-----------------------------------------------------------------------
if {[catch {update_timing} err]} {
    pt_fail "update_timing failed: $err"
}
update_timing > $LOG_DIR/update_timing.log

set_app_var timing_report_unconstrained_paths true
set_app_var case_analysis_sequential_propagation always
set_app_var case_analysis_propagate_through_icg true


set port_clock_root [get_ports [all_fanout -flat -clock_tree -level 0]]
set CG_cell [get_cells -quiet -of_objects [get_pins -hierarchical *ECK]]
group_path -name feedthrough_path -from [remove_from_collection [all_inputs] $port_clock_root] -to [all_outputs]
group_path -name in2reg_path -from [remove_from_collection [all_inputs] $port_clock_root] -to [all_registers]
group_path -name reg2out_path -from [all_registers] -to [all_outputs]
group_path -name reg2reg_path -from [all_registers] -to [all_registers]
group_path -name reg2gating_path -from [all_registers] -to [get_pins -of_objects [get_cell -hierarchical $CG_cell] -filter {full_name == E}]

pt_report [file join $REPORT_DIR ${DESIGN_NAME}.constraint.rpt] {report_constraints -all_violators -verbose -nosplit}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.clock.rpt] {report_clock -attributes -skew -nosplit}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.analysis_coverage.rpt] {report_analysis_coverage -nosplit}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.global_timing.rpt] {report_global_timing}

pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.setup.in2reg.rpt] {report_timing -group in2reg_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.setup.reg2out.rpt] {report_timing -group reg2out_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.setup.reg2reg.rpt] {report_timing -group reg2reg_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.setup.reg2gating.rpt] {report_timing -group reg2gating_path -max_paths   $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.setup.feedthrough.rpt] {report_timing -group feedthrough_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}

pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.hold.in2reg.rpt] {report_timing -group in2reg_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit -delay_type min}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.hold.reg2out.rpt] {report_timing -group reg2out_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit -delay_type min}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.hold.reg2reg.rpt] {report_timing -group reg2reg_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit -delay_type min}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.hold.reg2gating.rpt] {report_timing -group reg2gating_path -max_paths   $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit -delay_type min}
pt_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.hold.feedthrough.rpt] {report_timing -group feedthrough_path -max_paths $MAX_PATHS -nworst $NWORST_PATHS -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit -delay_type min}

# Save a PrimeTime session and the effective constraints for debug/reuse.
write_sdc [file join $OUTPUT_DIR ${DESIGN_NAME}.pt.sdc]
save_session [file join $OUTPUT_DIR ${DESIGN_NAME}.pt_session]

set PT_END_TIME [clock seconds]
puts "================================================================"
puts " PrimeTime STA completed: $DESIGN_NAME"
puts " Finished: [clock format $PT_END_TIME -format {%Y-%m-%d %H:%M:%S}]"
puts " Elapsed seconds: [expr {$PT_END_TIME - $PT_START_TIME}]"
puts " Reports: $REPORT_DIR"
puts " Outputs: $OUTPUT_DIR"
puts "================================================================"
exec touch DONE
quit
