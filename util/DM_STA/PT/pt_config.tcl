########################################################################
# pt_config.tcl
# Project-specific configuration for the PrimeTime STA flow.
########################################################################

#-----------------------------------------------------------------------
# Design
#-----------------------------------------------------------------------
set DESIGN_NAME     "m_vlsi_csr"

#-----------------------------------------------------------------------
# Synthesis inputs
#-----------------------------------------------------------------------
set SYN_OUTPUT_DIR  "/home/yellow/qnsc_usr7/MCU_guide_ws/IP/CSR/SYN/results"
set NETLIST_FILE    "${SYN_OUTPUT_DIR}/${DESIGN_NAME}.mapped.v"
set SDC_FILE        "${SYN_OUTPUT_DIR}/${DESIGN_NAME}.mapped.sdc"

#-----------------------------------------------------------------------
# Technology libraries
# LIBRARY_DIR may contain one or more directories with timing .db files.
# LINK_LIBRARIES must include standard-cell and macro/IP timing libraries
# for the selected analysis corner.
#-----------------------------------------------------------------------
set LIBRARY_DIR { /tools/pdk_libraries/SMIC/SMIC28NM/SMIC28HKMG/SMIC-28HKMG-7-Track-c31-Standard-Cell-Library/arm/smic/28hkmg/sc7mc_base_svt_c31/r1p0/db }
set LINK_LIBRARIES { sc7mc_28hkmg_base_svt_c31_ssg_typical_max_0p72v_m40c.db }

#-----------------------------------------------------------------------
# Outputs
#-----------------------------------------------------------------------
set REPORT_DIR      "reports"
set LOG_DIR         "logs"
set OUTPUT_DIR      "results"

# Optional PrimeTime application variables: {name value} pairs.
set APP_VARS        {}

# Message IDs to suppress, for example {UITE-489 PTE-075}.
set MESSAGE_FOR_SUPPRESS {}

# Timing-report controls.
set MAX_PATHS       100
set NWORST_PATHS    100
