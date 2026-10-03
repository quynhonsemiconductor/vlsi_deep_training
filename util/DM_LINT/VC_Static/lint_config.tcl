########################################################################
# lint_config.tcl
########################################################################

#-----------------------------------------------------------------------
# Design
#-----------------------------------------------------------------------

set TOP_MODULE              "m_vlsi_csr"
set RTL_FILELIST            "/home/yellow/qnsc_usr7/MCU_guide_ws/IP/CSR/RTL/filelist.f"

set RTL_DEFINES             "" 


#-----------------------------------------------------------------------
# PDK / Library
#-----------------------------------------------------------------------

set PDK_SETUP_FILE          ""

#-----------------------------------------------------------------------
# Session / Report
#-----------------------------------------------------------------------

set SESSION_DIR             "./session"
set SESSION_NAME            "${TOP_MODULE}_lint"

set REPORT_DIR              "./reports"

set REPORT_LINT_FULL        "${REPORT_DIR}/lint_full.rpt"
set REPORT_LINT_WAIVED      "${REPORT_DIR}/lint_waived.rpt"


#-----------------------------------------------------------------------
# Waiver
#-----------------------------------------------------------------------

set WAIVER_FILES           "" 

# WAVIER IP LIST
# EX:
# set WAIVER_IP_LIST { m_qnsc_i2c \
#                      m_qnsc_uart \
#                    }
set WAIVER_IP_LIST         {}
