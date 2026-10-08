#!/usr/bin/csh

if (! -d logs) then
    mkdir logs
endif

setenv CDC_GUI false 

vc_static_shell -no_init -batch -mode64 -lic_wait 300 -lic_report -f ./check_cdc.tcl -output_log_file logs/screen.log
