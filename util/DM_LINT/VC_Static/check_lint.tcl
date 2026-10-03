########################################################################
# check_lint.tcl
#
# Main VC Static LINT flow
########################################################################


########################################################################
# 0. START
########################################################################

set START_TIME [clock seconds]

puts ""
puts "============================================================"
puts "                 VC STATIC LINT"
puts "============================================================"
puts "Info: Start time [clock format ${START_TIME} -gmt false]"

########################################################################
# 1. ENVIRONMENT SETUP
########################################################################

#-----------------------------------------------------------------------
# GUI mode
#-----------------------------------------------------------------------

if {[info exists ::env(LINT_GUI)]} {
    set GUI $::env(LINT_GUI)
} else {
    set GUI false
}

puts "GUI       : $GUI"


#-----------------------------------------------------------------------
# Configuration
#-----------------------------------------------------------------------

#set SCRIPT_DIR [file dirname [file normalize [info script]]]

source -echo -verbose ./lint_config.tcl


#-----------------------------------------------------------------------
# Create output directories
#-----------------------------------------------------------------------

file mkdir $SESSION_DIR
file mkdir $REPORT_DIR


########################################################################
# 2. GUI MODE
########################################################################

if {$GUI == "true"} {

    puts ""
    puts "============================================================"
    puts "                 RESTORE LINT SESSION"
    puts "============================================================"

    set SESSION_PATH "${SESSION_DIR}/${SESSION_NAME}_rtdb"

    if {![file exists $SESSION_PATH]} {
        puts "ERROR: Session does not exist:"
        puts "  $SESSION_PATH"
        puts ""
        puts "Run batch LINT first."
        quit
    }

    puts "Restore session:"
    puts "  $SESSION_PATH"

    restore_session -session $SESSION_PATH


    #-------------------------------------------------------------------
    # Apply waiver files
    #-------------------------------------------------------------------

    if {$WAIVER_FILES != ""} {
	    foreach waiver_file $WAIVER_FILES {
                puts "Apply waiver:"
                puts "  $waiver_file"
                manage_waiver_file -add $waiver_file
	    }
    }


    #-------------------------------------------------------------------
    # Apply IP waiver
    #-------------------------------------------------------------------

    if {$WAIVER_IP_LIST != ""} {
        foreach ip $WAIVER_IP_LIST {
            puts "Apply waiver IP: $ip"
            waive_lint -ip $ip -add waiver_$ip 
        }
    }


    puts ""
    puts "Lint session restored."
    puts "GUI mode is ready."
    puts ""

    # Keep VC Static GUI alive
    view_activity
    return
}


########################################################################
# 3. LIBRARY / ENVIRONMENT SETUP
########################################################################

puts ""
puts "============================================================"
puts "                 LIBRARY SETUP"
puts "============================================================"

set LIBRARY_DIR ""
set TARGET_LIBRARY_FILES ""


#-----------------------------------------------------------------------
# Source PDK setup
#-----------------------------------------------------------------------

if {$PDK_SETUP_FILE ne ""} {

    if {[file exists $PDK_SETUP_FILE]} {

        puts "Source PDK setup:"
        puts "  $PDK_SETUP_FILE"

        source $PDK_SETUP_FILE

    } else {

        puts "ERROR: PDK setup file does not exist:"
        puts "  $PDK_SETUP_FILE"

        quit
    }
}


#set search_path "$LIBRARY_DIR /tools/eda/synopsys/syn/W-2024.09-SP3/dw/syn_ver"
set search_path "$LIBRARY_DIR ./"
set link_library "$TARGET_LIBRARY_FILES"

########################################################################
# 4. LINT CONFIGURATION
########################################################################

puts ""
puts "============================================================"
puts "                 LINT CONFIGURATION"
puts "============================================================"


set_app_var enable_lint true


#-----------------------------------------------------------------------
# LINT rule configuration
#
# Add project-specific VC Static lint configuration here.
#-----------------------------------------------------------------------

# Enable VC Spyglass Functional Lint
set_app_var lint_functional_mode true
set_app_var lint_enable_coverage_flow true 

# Example:
#
# configure_lint_tag ...
# configure_lint_methodology ...
configure_lint_setup -goal "QNSC_LINT_RULE"

source /tools/eda/synopsys/vc_static/W-2024.09-SP1/auxx/monet/tcl/GuideWare/block/initial_rtl/lint/lint_functional_rtl.tcl

########################################################################
# 5. ANALYZE RTL
########################################################################

puts ""
puts "============================================================"
puts "                 ANALYZE RTL"
puts "============================================================"

if {![file exists $RTL_FILELIST]} {

    puts "ERROR: RTL filelist does not exist:"
    puts "  $RTL_FILELIST"

    quit
}


#-----------------------------------------------------------------------
# Read RTL
#-----------------------------------------------------------------------

puts "RTL filelist:"
puts "  $RTL_FILELIST"
foreach fl $RTL_FILELIST {
	lappend analyze_vcs_filelist_pre "-f $fl"
}
set analyze_vcs_filelist [regsub -all "{|\}" $analyze_vcs_filelist_pre ""]
if {[string length $analyze_vcs_filelist] > 0} {
	analyze -format sverilog -vcs "$analyze_vcs_filelist" -define "$RTL_DEFINES -timescale=1ns/10ps"
}


########################################################################
# 6. ELABORATE
########################################################################

puts ""
puts "============================================================"
puts "                 ELABORATE"
puts "============================================================"

puts "Top module: $TOP_MODULE"

elaborate $TOP_MODULE


########################################################################
# 7. CHECK LINT
########################################################################

puts ""
puts "============================================================"
puts "                 CHECK LINT"
puts "============================================================"

check_lint


########################################################################
# 8. SAVE SESSION
########################################################################

puts ""
puts "============================================================"
puts "                 SAVE SESSION"
puts "============================================================"

set SESSION_PATH "${SESSION_DIR}/${SESSION_NAME}"

save_session -session $SESSION_PATH

########################################################################
# 9. WAIVER
########################################################################

puts ""
puts "============================================================"
puts "                 APPLY WAIVER"
puts "============================================================"


#-----------------------------------------------------------------------
# Global waiver
#-----------------------------------------------------------------------

if {$WAIVER_FILES != ""} {
        foreach waiver_file $WAIVER_FILES {
            puts "Apply waiver:"
            puts "  $waiver_file"
            manage_waiver_file -add $waiver_file
        }
}


#-------------------------------------------------------------------
# Apply IP waiver
#-------------------------------------------------------------------

if {$WAIVER_IP_LIST != ""} {
    foreach ip $WAIVER_IP_LIST {
        puts "Apply waiver IP: $ip"
        waive_lint -ip $ip -add waiver_$ip 
    }
}



########################################################################
# 10. REPORT
########################################################################

puts ""
puts "============================================================"
puts "                 REPORT"
puts "============================================================"


# Full lint report
report_violations \
    -app lint \
    -verbose \
    -include_compressed \
    -limit 0 \
    -file $REPORT_LINT_FULL


# Waived violations
report_violations \
    -app lint \
    -only_waived \
    -include_compressed \
    -verbose \
    -limit 0 \
    -file $REPORT_LINT_WAIVED


########################################################################
# 11. END
########################################################################

set END_TIME [clock seconds]
set RUN_TIME [expr {$END_TIME - $START_TIME}]

puts ""
puts "============================================================"
puts "                 LINT COMPLETE"
puts "============================================================"

puts "Start time : [clock format $START_TIME]"
puts "End time   : [clock format $END_TIME]"
puts "Runtime    : ${RUN_TIME} sec"

puts ""
puts "Session:"
puts "  $SESSION_PATH"

puts ""
puts "Reports:"
puts "  $REPORT_LINT_FULL"
puts "  $REPORT_LINT_WAIVED"

puts "============================================================"


quit
