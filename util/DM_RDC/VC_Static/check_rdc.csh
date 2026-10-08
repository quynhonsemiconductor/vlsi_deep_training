#!/usr/bin/csh

if (! -d logs) then
    mkdir logs
endif

setenv RDC_GUI false 

vc_static_shell -no_init -batch -mode64 -lic_wait 300 -lic_report -f ./check_rdc.tcl -output_log_file logs/screen.log
