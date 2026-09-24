# =============================================================================
# Filelist for the pwm block.
#
# This is the single place that says which files build this block, and in what
# order. CI lints the block through this file, so a file not listed here is not
# compiled and not checked.
#
# Rules:
#   - Upstream IP is LISTED here, never copied into rtl/. Paths are relative to
#     this file, so they start with ../../vendor/...
#   - Order matters. Packages and `define files first, then leaf modules, then
#     the modules that instantiate them, then our wrapper last.
#   - Anything under rtl/ is code written here. Anything under ../../vendor/ is
#     not ours -- see vendor/manifest.yml for its pinned commit and licence.
# =============================================================================

# ---- contract package ------------------------------------------------------
../top/rtl/qnsc_pkg.sv

# ---- upstream IP, in compile order -----------------------------------------
# lut_4x4.sv and out_filter.sv are not instantiated by apb_adv_timer.
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_clock_gating.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/adv_timer_apb_if.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/comparator.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/input_stage.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/prescaler.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/up_down_counter.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/timer_cntrl.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/timer_module.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/apb_adv_timer.sv

# ---- ours -------------------------------------------------------------------
# rtl/m_qnsc_wrap_pwm.sv is generated from rtl/emacs/m_qnsc_wrap_pwm.src.sv.
rtl/pulp_clock_gating.sv
rtl/m_qnsc_wrap_pwm.sv
