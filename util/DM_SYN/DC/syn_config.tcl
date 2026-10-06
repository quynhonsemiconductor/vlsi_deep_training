########################################################################
# syn_config.tcl
# Project-specific configuration for the Design Compiler flow.
########################################################################

# Design and RTL inputs
set DESIGN_NAME     "m_vlsi_csr"
set RTL_FILELIST    "/home/yellow/qnsc_usr7/MCU_guide_ws/IP/CSR/RTL/filelist.f"
set DEFINE_LIST     {}

# Technology and libraries. Populate these with the active PDK corner.
set LIBRARY_DIR { /tools/pdk_libraries/SMIC/SMIC28NM/SMIC28HKMG/SMIC-28HKMG-7-Track-c31-Standard-Cell-Library/arm/smic/28hkmg/sc7mc_base_svt_c31/r1p0/db }
set TARGET_LIBRARIES { sc7mc_28hkmg_base_svt_c31_ssg_typical_max_0p72v_m40c.db }       ;# e.g. {lib/stdcell_ss.db}

# Timing / low-power inputs
set SDC_FILE        "/home/yellow/qnsc_usr7/MCU_guide_ws/IP/CSR/SDC/SDC_top.tcl"       ;# e.g. constraints/${DESIGN_NAME}.sdc
set UPF_FILE        ""       ;# optional power intent

# Output directories
set REPORT_DIR      "reports"
set LOG_DIR         "logs"
set OUTPUT_DIR      "results"

# Optional Design Compiler application variables as {name value} pairs.
# Keep values as Tcl lists/strings appropriate for the named application var.
set APP_VARS        {}

# Message IDs to suppress, for example {UID-401 LINK-5}.
set MESSAGE_FOR_SUPPRESS {}

# Cell / instance restrictions. Patterns use Synopsys collection wildcards.
set DONT_TOUCH_CELLS {}
set DONT_USE_CELLS   {}
set SIZE_ONLY_CELLS  {}

# Clock-gating style. Leave empty to use the tool/library defaults.
# Example: {-sequential_cell latch -positive_edge_logic {and}}.
set CLOCK_GATING_STYLE {}
