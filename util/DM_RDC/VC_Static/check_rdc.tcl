########################################################################
# check_rdc.tcl
#
# Main VC Static RDC flow
########################################################################

foreach name [array names env] {
	set "$name" "$env($name)"
}

########################################################################
# 0. START
########################################################################

set START_TIME [clock seconds]

puts ""
puts "============================================================"
puts "                 VC STATIC RDC"
puts "============================================================"
puts "Info: Start time [clock format ${START_TIME} -gmt false]"

########################################################################
# 1. ENVIRONMENT SETUP
########################################################################

#-----------------------------------------------------------------------
# GUI mode
#-----------------------------------------------------------------------

if {[info exists ::env(RDC_GUI)]} {
    set GUI $::env(RDC_GUI)
} else {
    set GUI false
}

puts "GUI       : $GUI"


#-----------------------------------------------------------------------
# Configuration
#-----------------------------------------------------------------------

#set SCRIPT_DIR [file dirname [file normalize [info script]]]

source -echo -verbose ./rdc_config.tcl


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
    puts "                 RESTORE RDC SESSION"
    puts "============================================================"

    set SESSION_PATH "${SESSION_DIR}/${SESSION_NAME}_rtdb"

    if {![file exists $SESSION_PATH]} {
        puts "ERROR: Session does not exist:"
        puts "  $SESSION_PATH"
        puts ""
        puts "Run batch RDC first."
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
            waive_rdc -ip $ip -add waiver_$ip 
        }
    }


    puts ""
    puts "RDC session restored."
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

        source -echo -verbose $PDK_SETUP_FILE

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
# 4. RDC CONFIGURATION
########################################################################

puts ""
puts "============================================================"
puts "                 RDC CONFIGURATION"
puts "============================================================"


set_app_var enable_rdc true

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
# 7. POST RDC CONFIGURATION
########################################################################

puts ""
puts "============================================================"
puts "                POST  RDC CONFIGURATION"
puts "============================================================"

# Configure synchronizer detection
configure_cdc_nff_sync -allowed_modules m_qnsc_synch -depth 1

# Configure reset path multi-flop synchronizers detection
# configure_cdc_nff_sync -allowed_modules m_qnsc_synch -data_pin_connectivity tied_1 -depth 1

# Model all inputs into different virtual domain (if input ports has not constraint in any clock domain) and do not report any crossing on the output ports and enable verification for virtual domain
configure_unconstrained_ports -module ${TOP_MODULE} -input_model virtual_diff_bits -output_model no_cross -use_inferred_domains

# Model all inputs/outputs port of black-boxes into different virtual domain and enable verification for virtual domain
configure_unconstrained_ports -all_bbox -input_model virtual_diff_vector -output_model virtual_diff_vector -use_inferred_domains

# VC SpyGlass behavior becomes same as DC when reading SDC
set_app_var enable_dc_naming_style true


########################################################################
# 8. CONSTRAINT READING 
########################################################################

puts ""
puts "============================================================"
puts "                 CONSTRAINT READING"
puts "============================================================"

read_sdc $SDC_FILE
read_sdc $ADD_SDC_FILE


########################################################################
# 9. CHECK RDC 
########################################################################

puts ""
puts "============================================================"
puts "                 CHECK RDC"
puts "============================================================"

check_rdc


########################################################################
# 10. SAVE SESSION
########################################################################

puts ""
puts "============================================================"
puts "                 SAVE SESSION"
puts "============================================================"

set SESSION_PATH "${SESSION_DIR}/${SESSION_NAME}"

save_session -session $SESSION_PATH

########################################################################
# 11. WAIVER
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
        waive_rdc -ip $ip -add waiver_$ip 
    }
}



########################################################################
# 12. REPORT
########################################################################

puts ""
puts "============================================================"
puts "                 REPORT"
puts "============================================================"


# Full rdc report
report_rdc \
    -verbose \
    -include_compressed \
    -limit 0 \
    -file $REPORT_RDC_FULL


# Waived violations
report_rdc \
    -only_waived \
    -include_compressed \
    -verbose \
    -limit 0 \
    -file $REPORT_RDC_WAIVED


########################################################################
# 13. END
########################################################################

set END_TIME [clock seconds]
set RUN_TIME [expr {$END_TIME - $START_TIME}]

puts ""
puts "============================================================"
puts "                 RDC COMPLETE"
puts "============================================================"

puts "Start time : [clock format $START_TIME]"
puts "End time   : [clock format $END_TIME]"
puts "Runtime    : ${RUN_TIME} sec"

puts ""
puts "Session:"
puts "  $SESSION_PATH"

puts ""
puts "Reports:"
puts "  $REPORT_RDC_FULL"
puts "  $REPORT_RDC_WAIVED"

puts "============================================================"


quit
