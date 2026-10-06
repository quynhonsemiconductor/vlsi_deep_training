SCRIPT FOR STA (Static timing analysis) RUNNING WITH PT (PrimeTime of Synopsys)

Structure of this script:
	README.md            -> This file
	pt_config.tcl*       -> Configuration file for STA running, define top module, netlist path, output SDC path, ...
	pt_run.csh*          -> Run file, calling PT tool to run script pt_run.tcl for STA
	pt_run.tcl*          -> Main script for reading design, set application variable, timing analyze, report timing, ...

Usage:
	Step 1: Configure design name, netlist path, output SDC path,... in pt_config.tcl 
        Step 2: run script with command "./pt_run.csh"
        Step 3: Check the log files and reports
