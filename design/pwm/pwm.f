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

# ---- contract package, shared cells ----------------------------------------
../top/rtl/qnsc_pkg.sv
../common/rtl/qnsc_sync.sv

# ---- upstream IP, in compile order -----------------------------------------
# Clock gate cell behind pulp_clock_gating (see rtl/pulp_clock_gating.sv).
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_clock_gating.sv
# apb_adv_timer; lut_4x4.sv and out_filter.sv are not instantiated.
../../vendor/pulp-platform/apb_adv_timer/rtl/adv_timer_apb_if.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/comparator.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/input_stage.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/prescaler.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/up_down_counter.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/timer_cntrl.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/timer_module.sv
../../vendor/pulp-platform/apb_adv_timer/rtl/apb_adv_timer.sv

# ---- ours -------------------------------------------------------------------
rtl/pulp_clock_gating.sv
# Generated from rtl/emacs/m_qnsc_wrap_apb_adv_timer.src.sv by `make wrap BLOCK=pwm`.
rtl/m_qnsc_wrap_apb_adv_timer.sv
