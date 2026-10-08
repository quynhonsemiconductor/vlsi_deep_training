########################################################################
# cdc_config.tcl
########################################################################

#-----------------------------------------------------------------------
# Design
#-----------------------------------------------------------------------

set TOP_MODULE              "m_vlsi_csr"
set RTL_FILELIST            "/home/yellow/qnsc_usr7/MCU_guide_ws/IP/CSR/RTL/filelist.f"

set RTL_DEFINES             "" 

#-----------------------------------------------------------------------
# Constraint 
#-----------------------------------------------------------------------

set SDC_FILE "/home/yellow/qnsc_usr7/MCU_guide_ws/IP/CSR/SYN/results/m_vlsi_csr.precompile.sdc"
set ADD_SDC_FILE "./sdc_add.tcl"

#-----------------------------------------------------------------------
# PDK / Library
#-----------------------------------------------------------------------

set PDK_SETUP_FILE          ""

#-----------------------------------------------------------------------
# Session / Report
#-----------------------------------------------------------------------

set SESSION_DIR             "./session"
set SESSION_NAME            "${TOP_MODULE}_cdc"

set REPORT_DIR              "./reports"

set REPORT_CDC_FULL        "${REPORT_DIR}/cdc_full.rpt"
set REPORT_CDC_WAIVED      "${REPORT_DIR}/cdc_waived.rpt"


#-----------------------------------------------------------------------
# Waiver
#-----------------------------------------------------------------------

set WAIVER_FILES           "./cdc_waiver.tcl" 

# WAVIER IP LIST
# EX:
# set WAIVER_IP_LIST { m_qnsc_i2c \
#                      m_qnsc_uart \
#                    }
set WAIVER_IP_LIST         {}
