SCRIPT FOR SYNTHESIS RUNNING WITH DC (DESIGN COMPILER of Synopsys)

Structure of this script:
	README.md            -> This file
	syn_config.tcl*      -> Configuration file for synthesis, define top module, filelist, definelist, ...
	syn_run.csh*         -> Run file, calling DC tool to run script syn_run.tcl for synthesis
	syn_run.tcl*         -> Main script for reading design, set application variable, synthesize design, report, ...

Usage:
	Step 1: Configure design name, file list, definelist,... in syn_config.tcl 
        Step 2: run script with command "./syn_run.csh"
        Step 3: Check the log files and reports
