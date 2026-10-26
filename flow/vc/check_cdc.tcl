# VC Static CDC, batch. Needs the block SDC plus its reset/static declarations.
# If design/<block>/constraints/cdc_resets.tcl exists it is sourced as sdc_add.
source -echo ./cdc_config.tcl

file mkdir $SESSION_DIR
file mkdir $REPORT_DIR

analyze -format sverilog -vcs "-F $RTL_FILELIST" -define "$RTL_DEFINES -timescale=1ns/1ps"
elaborate $TOP_MODULE

if {$SDC_FILE ne "" && [file exists $SDC_FILE]} {
    puts "Reading SDC: $SDC_FILE"
    source $SDC_FILE
}
if {$ADD_SDC_FILE ne "" && [file exists $ADD_SDC_FILE]} {
    puts "Reading CDC declarations: $ADD_SDC_FILE"
    source $ADD_SDC_FILE
} else {
    puts "WARNING: no reset/static declarations found ($ADD_SDC_FILE)"
    puts "         CDC results will be incomplete. Write:"
    puts "           design/<block>/constraints/cdc_resets.tcl"
    puts "         with create_reset/create_static for each port."
}

check_cdc
save_session -session ${SESSION_DIR}/${SESSION_NAME}

if {$WAIVER_IP_LIST ne ""} {
    foreach ip $WAIVER_IP_LIST {
        puts "Apply waiver IP: $ip"
        waive_cdc -ip $ip -add waiver_$ip
    }
}
if {[info exists WAIVER_FILES] && $WAIVER_FILES ne ""} {
    foreach wf $WAIVER_FILES {
        puts "Apply CDC waiver: $wf"
        manage_waiver_file -add $wf
    }
}

report_violations -app cdc -verbose -include_compressed -limit 0 \
    -file ${REPORT_DIR}/cdc_full.rpt
report_violations -app cdc -only_waived -include_compressed -verbose -limit 0 \
    -file ${REPORT_DIR}/cdc_waived.rpt

quit
