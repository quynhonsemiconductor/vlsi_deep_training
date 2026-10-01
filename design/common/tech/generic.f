# =============================================================================
# Technology cells, generic implementation: simulation, CI, FPGA, open synthesis.
#
# Not listed in any block's filelist. Every flow appends design/common/tech/
# $(TECH).f after the block's own (TECH=generic unless set), so the same RTL is
# built on another technology by changing one variable. An ASIC library is a
# directory beside generic/ with the same modules and ports, and its <tech>.f.
# =============================================================================
generic/qnsc_clk_gate.sv
generic/qnsc_clk_buf.sv
generic/qnsc_clk_inv.sv
generic/qnsc_clk_mux.sv
generic/qnsc_clk_and.sv
