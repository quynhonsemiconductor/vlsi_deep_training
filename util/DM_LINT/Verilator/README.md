SCRIPT FOR LINT CHECK WITH Verilator

Structure of script:
 README.md           -> this file
 check_lint.csh      -> Main LINT check script, include design setting and run tool command

Usage:
	Step 1: Configure the TOP_MODULE, RTL_FILELIST, RTL_DEFINES, INCLUDE_DIRS, LIBRARY_FILES, WAIVER_FILES (if available)
        Step 2: run script with command "./check_lint.csh |& screen.log"
        Step 3: Check the log file for finding and verifying warnings/errors while reading design, check lint, print report, ... Check report file for LINT violations, and fix (when RTL has issue with LINT check) or create waiver file (when RTL issues can be waive)
