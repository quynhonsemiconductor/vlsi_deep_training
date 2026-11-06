# LINT configuration for dsram — auto-generated from dsram.f
# Regenerate: QSOC_SERVER=doelab-red make vc-lint BLOCK=dsram BRANCH=<branch>
set TOP_MODULE              "m_qnsc_wrap_dsram"
set RTL_FILELIST            "design/dsram/dsram.f"
set RTL_DEFINES             ""
set SESSION_DIR             "build/vc/lint/dsram/session"
set SESSION_NAME            "m_qnsc_wrap_dsram_lint"
set REPORT_DIR              "build/vc/lint/dsram/reports"
set WAIVER_IP_LIST          [list m_vlsi_arbiter m_vlsi_axfsm m_vlsi_axi4_sram m_vlsi_fifo m_vlsi_sram_misc ]
