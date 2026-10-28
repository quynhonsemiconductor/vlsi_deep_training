# LINT configuration for pwm
set TOP_MODULE              "m_qnsc_wrap_pwm"
set RTL_FILELIST            "design/pwm/pwm.f"
set RTL_DEFINES             ""
set SESSION_DIR             "build/vc/lint/pwm/session"
set SESSION_NAME            "m_qnsc_wrap_pwm_lint"
set REPORT_DIR              "build/vc/lint/pwm/reports"
set WAIVER_IP_LIST          [list adv_timer_apb_if apb_adv_timer comparator input_stage prescaler timer_cntrl timer_module up_down_counter ]
