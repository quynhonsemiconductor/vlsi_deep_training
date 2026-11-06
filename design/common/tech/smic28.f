# =============================================================================
# Technology cells, SMIC 28HKMG: ARM sc9mc_base_svt_c31 r1p0 (README "smic28").
#
# TECH=smic28 make <flow> BLOCK=<block>. Builds only where the PDK's Verilog model
# of the library is read too (the training server); CI uses generic.f.
# =============================================================================
smic28/qnsc_clk_gate.sv
smic28/qnsc_clk_buf.sv
smic28/qnsc_clk_inv.sv
smic28/qnsc_clk_and.sv
smic28/qnsc_dly.sv
smic28/qnsc_rst_sync.sv
smic28/qnsc_sync_cell.sv
smic28/qnsc_rst_filter.sv
