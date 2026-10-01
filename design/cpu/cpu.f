# Filelist for the cpu block. Order matters: packages, then leaves, then
# ibex_top, then our wrapper last. Upstream IP paths point at ../../vendor/,
# never copied into rtl/ -- see vendor/manifest.yml for commit + licence.

# Required: ibex's prim_assert.sv and common_cells' assertions.svh both
# define a macro named ASSERT; without this, common_cells' non-Verilator-safe
# redefinition wins and re-enables SVA syntax Verilator can't parse deep
# inside ibex_icache.sv. See vendor/manifest.yml for the full trace.
+define+ASSERTS_OFF

# Required: axi_mux.sv bundles a struct-based axi_mux (ours) and an
# interface-based axi_mux_intf sibling in one file. Without an explicit top,
# Verilator elaborates axi_mux_intf too and crashes (V3Width Internal Error).
--top-module m_qnsc_wrap_cpu

# ---- include directories ----------------------------------------------------
+incdir+../../vendor/lowrisc/opentitan/hw/dv/sv/dv_utils
+incdir+../../vendor/lowrisc/opentitan/hw/ip/prim/rtl
+incdir+../../vendor/lowrisc/opentitan/hw/ip/prim_generic/rtl
+incdir+../../vendor/pulp-platform/axi/include
+incdir+../../vendor/pulp-platform/common_cells/include

# cpu is IP, not integration: no qnsc_pkg import. Chip values arrive on
# i_cfg_* ports; the debug/DM window base is a tagged fixed value instead.

# lowRISC/ibex + opentitan (prim/prim_generic), FuseSoC compile order.
# ibex_trvk.sv (CHERIoT) is not listed: unused since BaseIsa=RV32I here.
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

# pulp-platform/axi + common_cells (pinned at axi's own Bender.lock commit).
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

# ours: CPU2AXI bridge (merges Ibex's two memory-style ports into one AXI4).
rtl/cpu2axi_pkg.sv
rtl/m_qnsc_cpu2axi.sv

# ours: the wrapper (generated, see rtl/emacs/Makefile).
rtl/emacs/m_qnsc_wrap_cpu.sv
