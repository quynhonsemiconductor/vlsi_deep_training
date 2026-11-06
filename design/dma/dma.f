# =============================================================================
# Filelist for the dma block.
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
+incdir+../../vendor/freecores/dma_axi/src/dma_axi32

# ---- upstream IP, in compile order -----------------------------------------
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_dual_core.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_apb_mux.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_reg.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_reg_core0.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_scatter8_1.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_top.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_wdt.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_arbiter.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ctrl.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_axim_wr.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_axim_cmd.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_axim_timeout.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_axim_wdata.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_joint_stall.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_fifo.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_stall.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_axim_resp.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_axim_rd.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_axim_rdata.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_channels.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_channels_apb_mux.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_channels_mux.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_or8.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_mux8.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_demux8.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_reg.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_reg_size.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_rawstat.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_offsets.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_remain.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_outs.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_calc.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_calc_addr.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_calc_size.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_min3.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_min2.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_calc_joint.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_periph_mux.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_fifo_ctrl.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_wr_slicer.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_swap_32.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_rd_slicer.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_fifo_ptr.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_fifo.v
../../vendor/freecores/dma_axi/src/dma_axi32/dma_axi32_core0_ch_empty.v
../../vendor/freecores/dma_axi/src/dma_axi32/prgen_delay.v

# ---- ours -------------------------------------------------------------------
rtl/m_qnsc_wrap_dma.sv
