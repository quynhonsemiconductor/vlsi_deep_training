# =============================================================================
# Filelist for the wdt block.
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


# ---- include directories ----------------------------------------------------
+incdir+../../vendor/lowrisc/opentitan/hw/ip/prim/rtl

# ---- upstream IP, in compile order -----------------------------------------
# lowRISC/opentitan @ aecc39ba: packages, prim, tlul, aon_timer
../../vendor/lowrisc/opentitan/hw/top_earlgrey/rtl/top_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_buf.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_flop.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_xnor2.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_22_16_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_22_16_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_28_22_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_28_22_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_39_32_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_39_32_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_64_57_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_64_57_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_72_64_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_72_64_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_22_16_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_22_16_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_39_32_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_39_32_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_72_64_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_72_64_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_76_68_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_hamming_76_68_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_22_16_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_22_16_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_28_22_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_28_22_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_39_32_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_39_32_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_64_57_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_64_57_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_72_64_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_72_64_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_22_16_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_22_16_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_39_32_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_39_32_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_72_64_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_72_64_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_76_68_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_secded_inv_hamming_76_68_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_cdc_rand_delay.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_sec_anchor_buf.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_sec_anchor_flop.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_util_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/lc_ctrl/rtl/lc_ctrl_state_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_flop_2sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_onehot_check.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_pkg.sv
../../vendor/lowrisc/opentitan/hw/top_earlgrey/rtl/autogen/top_racl_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/lc_ctrl/rtl/lc_ctrl_reg_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/lc_ctrl/rtl/lc_ctrl_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_diff_decode.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_edge_detector.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_reg_we_check.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_subreg_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_reg_cdc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_reg_cdc_arb.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_subreg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_subreg_arb.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_subreg_ext.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_data_integ_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_data_integ_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_cmd_intg_gen.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_cmd_intg_chk.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_rsp_intg_gen.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_rsp_intg_chk.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_alert_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_alert_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_lc_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_err.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_sync_reqack.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_pulse_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_intr_hw.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_adapter_host.sv
../../vendor/lowrisc/opentitan/hw/ip/tlul/rtl/tlul_adapter_reg.sv
../../vendor/lowrisc/opentitan/hw/ip/aon_timer/rtl/aon_timer_reg_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/aon_timer/rtl/aon_timer_reg_top.sv
../../vendor/lowrisc/opentitan/hw/ip/aon_timer/rtl/aon_timer_core.sv
../../vendor/lowrisc/opentitan/hw/ip/aon_timer/rtl/aon_timer.sv

# ---- ours -------------------------------------------------------------------
rtl/m_qnsc_wrap_wdt.sv
