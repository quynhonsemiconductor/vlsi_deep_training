#!/bin/csh -f

if (! -d logs/) then
    mkdir logs
endif
set log_date = `date "+%Y%m%d_%H%M%S"`
pt_shell -f ./pt_run.tcl -output_log_file logs/pt_log_${log_date}.log
