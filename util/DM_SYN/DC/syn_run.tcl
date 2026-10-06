########################################################################
# syn_run.tcl
# Batch RTL synthesis flow for Synopsys Design Compiler.
########################################################################

source -echo -verbose ./syn_config.tcl

proc syn_fail {message} {
    puts stderr "\nERROR: $message"
    quit
}

proc syn_report {path command} {
    redirect -file $path $command
}

proc syn_apply_patterns {patterns command_name description} {
    foreach pattern $patterns {
        set objects [get_lib_cells -quiet $pattern]
        if {[sizeof_collection $objects] == 0} {
            puts "WARNING: No library cells matched $description pattern '$pattern'"
        } else {
            $command_name $objects
        }
    }
}

proc syn_apply_instances {patterns command_name description} {
    foreach pattern $patterns {
        set objects [get_cells -hierarchical -quiet $pattern]
        if {[sizeof_collection $objects] == 0} {
            puts "WARNING: No instances matched $description pattern '$pattern'"
        } else {
            $command_name $objects
        }
    }
}

set SYN_START_TIME [clock seconds]
foreach directory [list $REPORT_DIR $LOG_DIR $OUTPUT_DIR [file join $OUTPUT_DIR ddc]] {
    if {[catch {file mkdir $directory} err]} { syn_fail "Cannot create $directory: $err" }
}

puts "================================================================"
puts " Design Compiler synthesis: $DESIGN_NAME"
puts " Started: [clock format $SYN_START_TIME -format {%Y-%m-%d %H:%M:%S}]"
puts "================================================================"

set_app_var search_path $LIBRARY_DIR
set_app_var synthetic_library dw_foundation.sldb
set_app_var target_library $TARGET_LIBRARIES
set_app_var link_library "* $TARGET_LIBRARIES $synthetic_library"

foreach _entry $APP_VARS {
    if {[llength $_entry] != 2} { syn_fail "APP_VARS entries must be {name value} pairs: $_entry" }
    lassign $_entry _app_name _app_value
    puts "Application variable: $_app_name = $_app_value"
    if {[catch {set_app_var $_app_name $_app_value} err]} { syn_fail "Unable to set $_app_name: $err" }
}
foreach _message $MESSAGE_FOR_SUPPRESS {
    suppress_message $_message
}

#-----------------------------------------------------------------------
# Guide Hierarchical Map (GHM) Flow
# Gnerate a Formality setup information file for efficient compare point matching in Formality
# Enable HDL Compiler to generate guide_hier_map guidance in SVF.
#-----------------------------------------------------------------------
set_svf $OUTPUT_DIR/$DESIGN_NAME.svf
set_app_var hdlin_enable_hier_map true

#-----------------------------------------------------------------------
# Analyze, elaborate, and save the elaborated checkpoint.
#-----------------------------------------------------------------------
puts "RTL filelist:"
puts "  $RTL_FILELIST"
foreach fl $RTL_FILELIST {
	lappend analyze_vcs_filelist_pre "-f $fl"
}
set analyze_vcs_filelist [regsub -all "{|\}" $analyze_vcs_filelist_pre ""]
if {[string length $analyze_vcs_filelist] > 0} {
	analyze -format sverilog -vcs "$analyze_vcs_filelist" -define "$DEFINE_LIST"
}

elaborate $DESIGN_NAME > $LOG_DIR/elab.log
current_design $DESIGN_NAME
# For Guide Hierarchy Map (GHM)
set_verification_top

if {[catch {link} err]} { syn_fail "Link failed: $err" }

write -format ddc -hierarchy -output [file join $OUTPUT_DIR ddc ${DESIGN_NAME}.elaborated.ddc]

#-----------------------------------------------------------------------
# UPF, pre-compile checks, and constraints.
#-----------------------------------------------------------------------
if {$UPF_FILE ne ""} {
    if {![file isfile $UPF_FILE]} { syn_fail "UPF file not found: $UPF_FILE" }
    puts "Loading UPF: $UPF_FILE"
    load_upf $UPF_FILE > $LOG_DIR/upf.log
}
check_design > $LOG_DIR/check_design_presyn.rpt
#write -format ddc -hierarchy -output [file join $OUTPUT_DIR ddc ${DESIGN_NAME}.precompile.ddc]

syn_apply_patterns $DONT_USE_CELLS set_dont_use "dont-use"
syn_apply_instances $DONT_TOUCH_CELLS set_dont_touch "dont-touch"
syn_apply_instances $SIZE_ONLY_CELLS set_size_only "size-only"

if {$SDC_FILE ne ""} {
    if {![file isfile $SDC_FILE]} { syn_fail "SDC file not found: $SDC_FILE" }
    puts "Reading constraints: $SDC_FILE"
    source -echo -verbose $SDC_FILE > $LOG_DIR/sdc.log
} else {
    puts "WARNING: SDC_FILE is empty; synthesis will use library/default constraints."
}
write_sdc [file join $OUTPUT_DIR ${DESIGN_NAME}.precompile.sdc]
write -format ddc -hierarchy -output [file join $OUTPUT_DIR ddc ${DESIGN_NAME}.constrained.ddc]

#-----------------------------------------------------------------------
# Compile and write the mapped design.
#-----------------------------------------------------------------------
if {[llength $CLOCK_GATING_STYLE] > 0} {
    if {[catch {eval set_clock_gating_style $CLOCK_GATING_STYLE} err]} {
        syn_fail "set_clock_gating_style failed: $err"
    }
}
set port_clock_root [get_ports [all_fanout -flat -clock_tree -level 0]]
set exist_regs [sizeof_collection [all_registers]]
set CG_cell [get_cells -quiet -of_objects [get_pins -hierarchical *ECK]]

group_path -name feedthrough_path -from [remove_from_collection [all_inputs] $port_clock_root] -to [all_outputs]
if {$exist_regs} {
     group_path -name in2reg_path -from [remove_from_collection [all_inputs] $port_clock_root] -to [all_registers]
     group_path -name reg2out_path -from [all_registers] -to [all_outputs]
     group_path -name reg2reg_path -from [all_registers] -to [all_registers]
     if {$CG_cell != ""} {
         group_path -name reg2gating_path -from [all_registers] -to [get_pins -of_objects [get_cell -hierarchical $CG_cell] -filter {name == E}]
     }
}

if {[catch {compile_ultra -gate_clock -scan -no_boundary_optimization -no_autoungroup -no_seq_output_inversion} err]} { syn_fail "compile_ultra failed: $err" }
write -format ddc -hierarchy -output [file join $OUTPUT_DIR ddc ${DESIGN_NAME}.b4cn.ddc]

change_names -rules verilog -hierarchy
write -format ddc -hierarchy -output [file join $OUTPUT_DIR ddc ${DESIGN_NAME}.mapped.ddc]
write -format verilog -hierarchy -output [file join $OUTPUT_DIR ${DESIGN_NAME}.mapped.v]

remove_path_group {feedthrough_path}
if {$exist_regs} {
    if {$CG_cell != ""} {
        remove_path_group {in2reg_path reg2out_path reg2gating_path}
    } else {
        remove_path_group {in2reg_path reg2out_path}
    }
}
write_sdc [file join $OUTPUT_DIR ${DESIGN_NAME}.mapped.sdc]

group_path -name feedthrough_path -from [remove_from_collection [all_inputs] $port_clock_root] -to [all_outputs]
if {$exist_regs} {
     group_path -name in2reg_path -from [remove_from_collection [all_inputs] $port_clock_root] -to [all_registers]
     group_path -name reg2out_path -from [all_registers] -to [all_outputs]
     group_path -name reg2reg_path -from [all_registers] -to [all_registers]
     if {$CG_cell != ""} {
         group_path -name reg2gating_path -from [all_registers] -to [get_pins -of_objects [get_cell -hierarchical $CG_cell] -filter {name == E}]
     }
}
create_block_abstraction
write -format ddc -hierarchy -output [file join $OUTPUT_DIR ddc ${DESIGN_NAME}.abs.ddc]

set_svf -off

#-----------------------------------------------------------------------
# Reports and post-compile checks.
#-----------------------------------------------------------------------
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.check_design.rpt] {check_design}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.qor.rpt] {report_qor}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.area.rpt] {report_area -hierarchy -nosplit}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.rpt] {report_timing -max_paths 50 -path full -nets -transition_time -capacitance -nosplit}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.constraints.rpt] {report_constraint -nosplit}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.constraints_detail.rpt] {report_constraint -all_violators -nosplit -verbose}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.references.rpt] {report_reference -hierarchy}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.power.rpt] {report_power -nosplit}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.clock.rpt] {report_clock -nosplit -attributes -skew -groups}
if {$exist_regs} {
    syn_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.in2reg.rpt] {report_timing -group in2reg_path -max_paths 100 -nworst 100 -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
    syn_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.reg2out.rpt] {report_timing -group reg2out_path -max_paths 100 -nworst 100 -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
    syn_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.reg2reg.rpt] {report_timing -group reg2reg_path -max_paths 100 -nworst 100 -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
    syn_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.reg2gating.rpt] {report_timing -group reg2gating_path -max_paths 100 -nworst 100 -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}
}
syn_report [file join $REPORT_DIR ${DESIGN_NAME}.timing.feedthrough.rpt] {report_timing -group feedthrough_path -max_paths 100 -nworst 100 -slack_lesser_than 0 -path full -nets -transition_time -capacitance -nosplit}


set SYN_END_TIME [clock seconds]
puts "================================================================"
puts " Synthesis completed: $DESIGN_NAME"
puts " Finished: [clock format $SYN_END_TIME -format {%Y-%m-%d %H:%M:%S}]"
puts " Elapsed seconds: [expr {$SYN_END_TIME - $SYN_START_TIME}]"
puts " Reports: $REPORT_DIR"
puts " Outputs: $OUTPUT_DIR"
puts "================================================================"
exec touch DONE
quit
