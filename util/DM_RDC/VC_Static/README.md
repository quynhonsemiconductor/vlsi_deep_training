SCRIPT FOR RDC CHECK WITH VC_STATIC (SYNOPSYS)

Structure of script:
	 README.md               -> This file
	 rdc_config.tcl          -> Configure file, use for configure the design name, filelist path, ...
	 rdc_waiver.tcl          -> Waiver file for specific design
	 check_rdc.csh           -> Call tool for RDC check
	 check_rdc.tcl           -> Main RDC check script, use for setup RDC configuration, read design, check RDC, report, ...
	 sdc_add.tcl             -> Addition constraint for design, can include reset declaration, static signal declaration, ...

There are 2 appliable flows:
	1/ RDC_GUI = false (set in check_rdc.csh): check RDC for specific design and print log, report, apply waiver, save session, and quit tool.
        2/ RDC_GUI = true  (set in check_rdc.csh): restore the saved session, and open the GUI for easier checking, verify, create waiver, ... 

Usage:
	Step 1: Configure the module name, filelist, waiver file, definelist, ... in rdc_config.tcl
        Step 2 (Option): setting true (default is false) for RDC_GUI to open the GUI with saved session (Not apply for first run)
        Step 3: run script with command "./check_rdc.csh"
        Step 4: Check the log file for finding and verifying warnings/errors while reading design, check rdc, print report, ... Check report file for RDC violations, and fix (when RTL/SDC has issue with RDC check) or create waiver file (when RDC issues can be waive)
