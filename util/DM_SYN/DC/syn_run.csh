#!/bin/csh -f

if (! -d logs/) then
    mkdir logs
endif
set log_date = `date "+%Y%m%d_%H%M%S"`
dc_shell -f ./syn_run.tcl -output_log_file logs/syn_log_${log_date}.log 
