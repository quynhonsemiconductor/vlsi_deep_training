# =============================================================================
# Filelist for the cpu block.
#
# This is the single place that says which files build this block, and in what
# order. CI lints the block through this file, so a file not listed here is not
# compiled and not checked.
#
# Rules:
#   - Upstream IP is LISTED here, never copied into rtl/. Paths are relative to
#     this file, so they start with ../../vendor/...
#   - Order matters. Packages and `define files first, then leaf modules, then
#     the IP's top, then our wrapper last.
#   - Anything under rtl/ is code written here. Anything under ../../vendor/ is
#     not ours -- see vendor/manifest.yml for its pinned commit and licence.
#
# +define+ASSERTS_OFF is REQUIRED here, not optional. Both lowRISC/ibex
# (via prim_assert.sv) and pulp-platform/common_cells (via
# include/common_cells/assertions.svh) define a macro literally named ASSERT
# and a gating flag literally named INC_ASSERT. prim_assert.sv makes its own
# ASSERT a Verilator-safe no-op when VERILATOR is defined (always true here);
# common_cells' assertions.svh is not Verilator-aware and unconditionally
# (re)defines the SAME macro name for any non-SYNTHESIS/non-XSIM build, silently
# overriding lowRISC's no-op for the rest of this compile unit. Without
# ASSERTS_OFF, that re-enables real assert property(...) text buried inside
# ibex's own CDC primitive (prim_sync_reqack.sv, pulled in transitively by
# ibex_icache.sv), containing throughout/[->1] SVA sequence syntax Verilator
# cannot parse -- a spurious, hard-to-trace lint failure that touches none of
# this block's own code. See vendor/manifest.yml's pulp-platform/axi and
# pulp-platform/common_cells entries for the full explanation.
+define+ASSERTS_OFF

# --top-module is REQUIRED here too, not optional. flow/lint/lint_all.sh does
# not pass --top-module itself, and pulp-platform/axi/src/axi_mux.sv bundles
# BOTH the struct-based axi_mux we actually instantiate AND an interface-based
# axi_mux_intf sibling in the same file (same for axi_lite_to_axi/
# axi_lite_to_axi_intf). Without an explicit top, Verilator treats every
# parentless module -- including axi_mux_intf, whose AXI_BUS/AXI_LITE
# interface ports are only valid with the real parameter context an actual
# instantiation would provide -- as its own elaboration root, which crashes
# Verilator 5.020 with an Internal Error in V3Width (SEL has no expected
# width) rather than a normal lint diagnostic. Naming our own top here
# sidesteps it entirely: only m_qnsc_wrap_cpu and what it actually
# instantiates gets elaborated, exactly like a real top-level integration
# would only ever reach the struct-based axi_mux.
--top-module m_qnsc_wrap_cpu

# ---- include directories ----------------------------------------------------
+incdir+../../vendor/lowrisc/opentitan/hw/dv/sv/dv_utils
+incdir+../../vendor/lowrisc/opentitan/hw/ip/prim/rtl
+incdir+../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl
+incdir+../../vendor/pulp-platform/axi/include
+incdir+../../vendor/pulp-platform/common_cells/include

# ---- shared contract package (../../design/top/rtl/qnsc_pkg.sv is GENERATED
# ---- from util/qsoc_contract.yml -- see CONTRIBUTING.md, "Never retype a
# ---- shared number"). Must precede anything importing it. ------------------
../../design/top/rtl/qnsc_pkg.sv

# ---- upstream IP: lowRISC/ibex + lowRISC/opentitan (prim/prim_generic), ----
# ---- in FuseSoC-resolved compile order --------------------------------------
# ibex_trvk.sv (CHERIoT revocation bitmap) is deliberately NOT listed: it is
# only instantiated inside ibex_top's "if (BaseIsa == BaseIsaRV32IorCHERIoT)"
# generate branch, and this block's BaseIsa is plain BaseIsaRV32I -- confirmed
# by lint (removing ibex_trvk.sv from the filelist changes nothing but the
# warning count), not just assumed. See vendor/manifest.yml's lowRISC/ibex
# entry.
../../vendor/lowrisc/ibex/rtl/ibex_pkg.sv
../../vendor/lowrisc/ibex/rtl/ibex_cheriot_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_ram_1p_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_ram_2p_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_rom_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_ram_1r1w_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_cipher_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_and2.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_buf.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_clock_buf.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_clock_gating.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_flop.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_flop_no_rst.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_usb_diff_rx.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_xnor2.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_xor2.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_pad_wrapper_pkg.sv
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
../../vendor/lowrisc/ibex/rtl/ibex_icache.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_cdc_rand_delay.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_subst_perm.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_present.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_prince.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_count_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_count.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_clock_mux2.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_pad_attr.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_pad_wrapper.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_ram_1p.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_ram_1r1w.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_ram_2p.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_rom.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_lfsr.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_sec_anchor_buf.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_sec_anchor_flop.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_util_pkg.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_clock_inv.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_flop_2sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_flop_en.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi4_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi4_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi4_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi8_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi8_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi8_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi12_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi12_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi12_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi16_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi16_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi16_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi20_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi20_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi20_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi24_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi24_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi24_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi28_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi28_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi28_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi32_sender.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi32_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_mubi32_dec.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_onehot_enc.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_onehot_mux.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_ram_1p_adv.sv
../../vendor/lowrisc/ibex/rtl/ibex_cheriot_ex.sv
../../vendor/lowrisc/ibex/rtl/ibex_alu.sv
../../vendor/lowrisc/ibex/rtl/ibex_branch_predict.sv
../../vendor/lowrisc/ibex/rtl/ibex_compressed_decoder.sv
../../vendor/lowrisc/ibex/rtl/ibex_controller.sv
../../vendor/lowrisc/ibex/rtl/ibex_cs_registers.sv
../../vendor/lowrisc/ibex/rtl/ibex_csr.sv
../../vendor/lowrisc/ibex/rtl/ibex_counter.sv
../../vendor/lowrisc/ibex/rtl/ibex_decoder.sv
../../vendor/lowrisc/ibex/rtl/ibex_ex_block.sv
../../vendor/lowrisc/ibex/rtl/ibex_fetch_fifo.sv
../../vendor/lowrisc/ibex/rtl/ibex_id_stage.sv
../../vendor/lowrisc/ibex/rtl/ibex_if_stage.sv
../../vendor/lowrisc/ibex/rtl/ibex_load_store_unit.sv
../../vendor/lowrisc/ibex/rtl/ibex_multdiv_fast.sv
../../vendor/lowrisc/ibex/rtl/ibex_multdiv_slow.sv
../../vendor/lowrisc/ibex/rtl/ibex_prefetch_buffer.sv
../../vendor/lowrisc/ibex/rtl/ibex_pmp.sv
../../vendor/lowrisc/ibex/rtl/ibex_wb_stage.sv
../../vendor/lowrisc/ibex/rtl/ibex_dummy_instr.sv
../../vendor/lowrisc/ibex/rtl/ibex_core.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_fifo_async_sram_adapter.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_fifo_async_simple.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_fifo_async.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_fifo_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_fifo_sync_cnt.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_clock_div.sv
../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl/prim_rst_sync.sv
../../vendor/lowrisc/opentitan/hw/ip/prim/rtl/prim_ram_1p_scr.sv
../../vendor/lowrisc/ibex/rtl/ibex_register_file_ff.sv
../../vendor/lowrisc/ibex/rtl/ibex_register_file_fpga.sv
../../vendor/lowrisc/ibex/rtl/ibex_register_file_latch.sv
../../vendor/lowrisc/ibex/rtl/ibex_lockstep.sv
../../vendor/lowrisc/ibex/rtl/ibex_top.sv

# ---- upstream IP: pulp-platform/axi + pulp-platform/common_cells ------------
# common_cells is vendored at the OLDER commit axi's own Bender.lock pins
# (db42769, pre-rename cc_ naming), not at a newer common_cells release --
# see vendor/manifest.yml's pulp-platform/common_cells entry.
../../vendor/pulp-platform/axi/src/axi_pkg.sv
../../vendor/pulp-platform/common_cells/src/cc_pkg.sv
../../vendor/pulp-platform/common_cells/src/cc_lzc.sv
../../vendor/pulp-platform/common_cells/src/cc_fifo.sv
../../vendor/pulp-platform/common_cells/src/cc_spill_register_flushable.sv
../../vendor/pulp-platform/common_cells/src/cc_rr_arb_tree.sv
../../vendor/pulp-platform/common_cells/src/cc_spill_register.sv
../../vendor/pulp-platform/axi/src/axi_id_prepend.sv
../../vendor/pulp-platform/axi/src/axi_intf.sv
../../vendor/pulp-platform/axi/src/axi_lite_from_mem.sv
../../vendor/pulp-platform/axi/src/axi_lite_to_axi.sv
../../vendor/pulp-platform/axi/src/axi_from_mem.sv
../../vendor/pulp-platform/axi/src/axi_mux.sv

# ---- ours: CPU2AXI bridge (self-designed merge of Ibex's two memory-style ---
# ---- ports into one AXI4 master; axi_from_mem/axi_mux themselves are IP) ----
rtl/cpu2axi_pkg.sv
rtl/m_qnsc_cpu2axi.sv

# ---- ours: QNSC-naming-rule wrappers, generated via Emacs verilog-mode ------
# ---- AUTOINST/AUTO_TEMPLATE from rtl/emacs/*.src.sv -- see rtl/emacs/Makefile
rtl/emacs/m_qnsc_wrap_ibex.sv
rtl/emacs/m_qnsc_wrap_cpu2axi.sv
rtl/emacs/m_qnsc_wrap_cpu.sv
