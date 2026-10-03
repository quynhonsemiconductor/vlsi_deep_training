#!/usr/bin/csh -f

########################################################################
# Verilator LINT Check
########################################################################
#
# Usage:
#     ./check_lint.csh
#
# Configuration:
#     Modify the CONFIGURATION section below.
#
########################################################################


########################################################################
# 0. CONFIGURATION
########################################################################

#-----------------------------------------------------------------------
# Design
#-----------------------------------------------------------------------

set TOP_MODULE       = "m_vlsi_csr"

set RTL_FILELIST     = "/home/stork/QNSC_MCU/CSR/APB-CSR-Generator/RTL/filelist.f"

# Verilator defines
#
# Example:
#   set RTL_DEFINES = ( "SYNTHESIS" "ASIC" "DEBUG" )
#
set RTL_DEFINES      = ( )


#-----------------------------------------------------------------------
# Include directories
#-----------------------------------------------------------------------

# Example:
#   set INCLUDE_DIRS = ( \
#       "/path/to/include" \
#       "/path/to/another/include" \
#   )
#
set INCLUDE_DIRS     = ( )


#-----------------------------------------------------------------------
# Library files
#-----------------------------------------------------------------------

# Verilator -v library files
#
# Example:
#   set LIBRARY_FILES = ( \
#       "/path/to/std_cell.v" \
#       "/path/to/memory_model.v" \
#   )
#
set LIBRARY_FILES    = ( )


#-----------------------------------------------------------------------
# Waiver files
#-----------------------------------------------------------------------

# Verilator Control / Waiver files
#
# Example:
#   set WAIVER_FILES = ( \
#       "./waiver/lint.vlt" \
#   )
#
set WAIVER_FILES     = ( "./waiver/lint.vlt" )


#-----------------------------------------------------------------------
# Verilator options
#-----------------------------------------------------------------------

set VERILATOR_FLAGS = ( \
    "--lint-only" \
    "--Wall" \
)


########################################################################
# 1. OUTPUT DIRECTORIES
########################################################################

set REPORT_DIR       = "./reports"
#set LOG_DIR          = "./logs"
set SESSION_DIR      = "./session"

set REPORT_FILE      = "${REPORT_DIR}/${TOP_MODULE}_lint.rpt"
#set LOG_FILE         = "${LOG_DIR}/${TOP_MODULE}_lint.log"
set SESSION_FILE     = "${SESSION_DIR}/${TOP_MODULE}_lint.cmd"
set VERSION_FILE     = "${SESSION_DIR}/${TOP_MODULE}_lint.version"


########################################################################
# 2. CHECK ENVIRONMENT
########################################################################

if (! -e "$RTL_FILELIST") then
    echo "ERROR: RTL filelist does not exist:"
    echo "  $RTL_FILELIST"
    exit 1
endif


foreach waiver_file ($WAIVER_FILES)
    if (! -e "$waiver_file") then
        echo "ERROR: Waiver file does not exist:"
        echo "  $waiver_file"
        exit 1
    endif
end


foreach library_file ($LIBRARY_FILES)
    if (! -e "$library_file") then
        echo "ERROR: Library file does not exist:"
        echo "  $library_file"
        exit 1
    endif
end


########################################################################
# 3. CREATE OUTPUT DIRECTORIES
########################################################################

if (! -d "$REPORT_DIR")  mkdir -p "$REPORT_DIR"
#if (! -d "$LOG_DIR")     mkdir -p "$LOG_DIR"
if (! -d "$SESSION_DIR") mkdir -p "$SESSION_DIR"


########################################################################
# 4. BUILD VERILATOR COMMAND
########################################################################

set CMD = ( verilator )

#-----------------------------------------------------------------------
# Verilator options
#-----------------------------------------------------------------------

foreach flag ($VERILATOR_FLAGS)
    set CMD = ( $CMD "$flag" )
end


#-----------------------------------------------------------------------
# Top module
#-----------------------------------------------------------------------

set CMD = ( $CMD "--top-module" "$TOP_MODULE" )

#-----------------------------------------------------------------------
# Waiver files
#
# Waiver/control files must appear before the RTL they affect.
# Therefore they are inserted before the RTL filelist.
#
# If the current Verilator version/project requires strict ordering,
# keep waiver files in the filelist instead.
#-----------------------------------------------------------------------

set WAIVER_CMD = ( )

foreach waiver_file ($WAIVER_FILES)
    set WAIVER_CMD = ( $WAIVER_CMD "$waiver_file" )
end

set CMD = ( $CMD $WAIVER_CMD)

#-----------------------------------------------------------------------
# RTL filelist
#-----------------------------------------------------------------------

set CMD = ( $CMD "-f" "$RTL_FILELIST" )


#-----------------------------------------------------------------------
# Defines
#-----------------------------------------------------------------------

foreach define ($RTL_DEFINES)
    set CMD = ( $CMD "-D$define" )
end


#-----------------------------------------------------------------------
# Include directories
#-----------------------------------------------------------------------

foreach include_dir ($INCLUDE_DIRS)
    set CMD = ( $CMD "-I$include_dir" )
end


#-----------------------------------------------------------------------
# Library files
#-----------------------------------------------------------------------

foreach library_file ($LIBRARY_FILES)
    set CMD = ( $CMD "-v" "$library_file" )
end

# Output reference waiver
set CMD = ( $CMD "--waiver-output" "reference_waiver.vlt")

########################################################################
# 5. DISPLAY CONFIGURATION
########################################################################

echo ""
echo "============================================================"
echo "                 VERILATOR LINT"
echo "============================================================"
echo ""
echo "Top module     : $TOP_MODULE"
echo "RTL filelist   : $RTL_FILELIST"
echo "Report         : $REPORT_FILE"
#echo "Log            : $LOG_FILE"
echo "Session        : $SESSION_FILE"
echo ""


########################################################################
# 6. SAVE SESSION INFORMATION
########################################################################

echo "# Verilator LINT command" > "$SESSION_FILE"
echo "#" >> "$SESSION_FILE"
echo "# Top module   : $TOP_MODULE" >> "$SESSION_FILE"
echo "# Filelist     : $RTL_FILELIST" >> "$SESSION_FILE"
echo "#" >> "$SESSION_FILE"

echo -n "verilator " >> "$SESSION_FILE"

foreach flag ($VERILATOR_FLAGS)
    echo -n "$flag " >> "$SESSION_FILE"
end

echo -n "--top-module $TOP_MODULE " >> "$SESSION_FILE"

foreach waiver_file ($WAIVER_FILES)
    echo -n "$waiver_file " >> "$SESSION_FILE"
end

echo -n "-f $RTL_FILELIST " >> "$SESSION_FILE"

foreach define ($RTL_DEFINES)
    echo -n "-D$define " >> "$SESSION_FILE"
end

foreach include_dir ($INCLUDE_DIRS)
    echo -n "-I$include_dir " >> "$SESSION_FILE"
end

foreach library_file ($LIBRARY_FILES)
    echo -n "-v $library_file " >> "$SESSION_FILE"
end

echo "" >> "$SESSION_FILE"


########################################################################
# 7. SAVE VERILATOR VERSION
########################################################################

verilator --version > "$VERSION_FILE"


########################################################################
# 8. RUN LINT
########################################################################

echo ""
echo "============================================================"
echo "                 RUN LINT"
echo "============================================================"
echo ""

# Execute Verilator.
#
# stdout + stderr:
#     logs/    -> complete execution log
#     reports/ -> lint report
#
# tee allows the result to be displayed on screen and saved.
#

$CMD |& tee "$REPORT_FILE"

set STATUS = $status

#cat "$LOG_FILE" | tee "$REPORT_FILE"


########################################################################
# 9. RESULT
########################################################################

echo ""
echo "============================================================"

if ($STATUS == 0) then
    echo "VERILATOR LINT PASSED"
else
    echo "VERILATOR LINT FAILED"
endif

echo "============================================================"
echo ""
echo "Report : $REPORT_FILE"
#echo "Log    : $LOG_FILE"
echo "Session: $SESSION_FILE"
echo ""

exit $STATUS
