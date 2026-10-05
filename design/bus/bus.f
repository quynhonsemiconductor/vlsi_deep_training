# =============================================================================
# Filelist for the bus block.
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
#
# --top-module is REQUIRED here, not optional. pulp-platform/axi/src/axi_mux.sv
# (pulled in transitively by axi_xbar) bundles both the struct-based axi_mux we
# actually use and an interface-based axi_mux_intf sibling in the same file;
# without an explicit top, Verilator elaborates every parentless module as its
# own root, and axi_mux_intf's AXI_BUS/AXI_LITE interface ports are only valid
# with the parameter context a real instantiation provides. Same issue, same
# fix, as design/cpu/cpu.f.
# =============================================================================
--top-module m_qnsc_wrap_bus

# ---- include directories ----------------------------------------------------
+incdir+../../vendor/pulp-platform/axi/include
+incdir+../../vendor/pulp-platform/common_cells/include

# ---- shared contract package (../../design/top/rtl/qnsc_pkg.sv is GENERATED
# ---- from util/qsoc_contract.yml -- see CONTRIBUTING.md, "Never retype a
# ---- shared number"). bus is integration (design/README.md, "Shared numbers:
# ---- who may use qnsc_pkg"), so it imports this directly. Must precede
# ---- anything importing it. --------------------------------------------------
../../design/top/rtl/qnsc_pkg.sv

# ---- upstream IP: pulp-platform/axi + pulp-platform/common_cells -----------
../../vendor/pulp-platform/axi/src/axi_pkg.sv
../../vendor/pulp-platform/common_cells/src/cc_pkg.sv
../../vendor/pulp-platform/common_cells/src/cc_lzc.sv
../../vendor/pulp-platform/common_cells/src/cc_fifo.sv
../../vendor/pulp-platform/common_cells/src/cc_spill_register_flushable.sv
../../vendor/pulp-platform/common_cells/src/cc_rr_arb_tree.sv
../../vendor/pulp-platform/common_cells/src/cc_spill_register.sv
../../vendor/pulp-platform/common_cells/src/cc_delta_counter.sv
../../vendor/pulp-platform/common_cells/src/cc_counter.sv
../../vendor/pulp-platform/common_cells/src/cc_stream_register.sv
../../vendor/pulp-platform/common_cells/src/cc_addr_decode_dync.sv
../../vendor/pulp-platform/common_cells/src/cc_addr_decode.sv
../../vendor/pulp-platform/common_cells/src/cc_fall_through_register.sv
../../vendor/pulp-platform/common_cells/src/cc_onehot_to_bin.sv
../../vendor/pulp-platform/common_cells/src/cc_id_queue.sv
../../vendor/pulp-platform/axi/src/axi_intf.sv
../../vendor/pulp-platform/axi/src/axi_id_prepend.sv
../../vendor/pulp-platform/axi/src/axi_mux.sv
../../vendor/pulp-platform/axi/src/axi_cut.sv
../../vendor/pulp-platform/axi/src/axi_multicut.sv
../../vendor/pulp-platform/axi/src/axi_err_slv.sv
../../vendor/pulp-platform/axi/src/axi_demux_id_counters.sv
../../vendor/pulp-platform/axi/src/axi_demux_simple.sv
../../vendor/pulp-platform/axi/src/axi_demux.sv
../../vendor/pulp-platform/axi/src/axi_xbar_unmuxed.sv
../../vendor/pulp-platform/axi/src/axi_xbar.sv
../../vendor/pulp-platform/axi/src/axi_burst_splitter_gran.sv
../../vendor/pulp-platform/axi/src/axi_burst_splitter.sv
../../vendor/pulp-platform/axi/src/axi_atop_filter.sv
../../vendor/pulp-platform/axi/src/axi_to_axi_lite.sv
../../vendor/pulp-platform/axi/src/axi_lite_to_apb.sv

# ---- ours -------------------------------------------------------------------
rtl/s_bus_pkg.sv
# P_BUS's router: generated (nguyenquanicd/APB-DEC-Generator), committed
# alongside its spreadsheet input in util/gen/p_bus_apb_dec/ -- see
# vendor/manifest.yml. Plain module, no package/import, so it has no
# ordering requirement beyond "before the wrapper that instantiates it".
../../util/gen/p_bus_apb_dec/m_qnsc_p_bus_dec.sv
rtl/m_qnsc_wrap_bus.sv
