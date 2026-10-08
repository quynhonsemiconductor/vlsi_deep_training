SCRIPT FOR CDC CHECK WITH VC_STATIC (SYNOPSYS)

Structure of script:
	 README.md               -> This file
	 cdc_config.tcl          -> Configure file, use for configure the design name, filelist path, ...
	 cdc_waiver.tcl          -> Waiver file for specific design
	 check_cdc.csh           -> Call tool for CDC check
	 check_cdc.tcl           -> Main CDC check script, use for setup CDC configuration, read design, check CDC, report, ...
	 sdc_add.tcl             -> Addition constraint for design, can include reset declaration, static signal declaration, ...

There are 2 appliable flows:
	1/ CDC_GUI = false (set in check_cdc.csh): check CDC for specific design and print log, report, apply waiver, save session, and quit tool.
        2/ CDC_GUI = true  (set in check_cdc.csh): restore the saved session, and open the GUI for easier checking, verify, create waiver, ... 

Usage:
	Step 1: Configure the module name, filelist, waiver file, definelist, ... in cdc_config.tcl
        Step 2 (Option): setting true (default is false) for CDC_GUI to open the GUI with saved session (Not apply for first run)
        Step 3: run script with command "./check_cdc.csh"
        Step 4: Check the log file for finding and verifying warnings/errors while reading design, check cdc, print report, ... Check report file for CDC violations, and fix (when RTL/SDC has issue with CDC check) or create waiver file (when CDC issues can be waive)
