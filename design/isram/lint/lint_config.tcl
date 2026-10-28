# LINT configuration for isram — auto-generated from isram.f
# Regenerate: QSOC_SERVER=doelab-red make vc-lint BLOCK=isram BRANCH=<branch>
set TOP_MODULE              "m_qnsc_wrap_isram"
set RTL_FILELIST            "design/isram/isram.f"
set RTL_DEFINES             ""
set SESSION_DIR             "build/vc/lint/isram/session"
set SESSION_NAME            "m_qnsc_wrap_isram_lint"
set REPORT_DIR              "build/vc/lint/isram/reports"
set WAIVER_IP_LIST          [list m_vlsi_arbiter m_vlsi_axfsm m_vlsi_axi4_sram m_vlsi_fifo m_vlsi_sram_misc ]
