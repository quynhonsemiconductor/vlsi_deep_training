SCRIPT FOR LINT CHECK WITH VC_STATIC (SYNOPSYS)

Structure of script:
 README.md                     -> This file
 check_lint.csh                -> Calling tool for LINT check
 check_lint.tcl                -> Main LINT check script, use for setup LINT configuration, read design, check lint, report, ...
 lint_config.tcl               -> Configure file, use for configure the design name, filelist path, ...

There are 2 appliable flows:
	1/ LINT_GUI = false (set in check_lint.csh): check lint for specific design and print log, report, apply waiver, save session, and quit tool.
        2/ LINT_GUI = true  (set in check_lint.csh): restore the saved session, and open the GUI for easier checking, verify, create waiver, ... 

Usage:
	Step 1: Configure the module name, filelist, waiver file, definelist, ... in lint_config.tcl
        Step 2 (Option): setting true (default is false) for LINT_GUI to open the GUI with saved session (Not apply for first run)
        Step 3: run script with command "./check_lint.csh"
        Step 4: Check the log file for finding and verifying warnings/errors while reading design, check lint, print report, ... Check report file for LINT violations, and fix (when RTL has issue with LINT check) or create waiver file (when RTL issues can be waive)
