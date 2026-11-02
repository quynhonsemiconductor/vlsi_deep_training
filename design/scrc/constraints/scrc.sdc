# =============================================================================
# SDC of the scrc block (m_qnsc_scrc), from flow/sdc_template.sdc.
# Constrains the block for SYN (DC), CDC/RDC (VC Static) and STA (PT).
# QNSC_SCRC_MAS V3.4: 5 (interface), 7.1-7.3 (clock and reset path).
# =============================================================================

# ---- 1. Clock ---------------------------------------------------------------
# CLKIN is the root of every chip clock: 20 MHz, 50% duty, no PLL (contract
# meta.clock_mhz). It is named clk_cpu, the chip root of flow/sta/README.md.
# The 18 o_clk_<d> are this clock through the root buffer and one clock gate
# (qnsc_clk_gate): STA propagates the clock through the gate, so they need no
# clock of their own here; design/top names them by cluster.
create_clock -name clk_cpu -period 50.0 [get_ports i_clk_pad]
set_clock_uncertainty -setup 0.5 [get_clocks clk_cpu]

# ---- 2. Input / Output delays ------------------------------------------------
# APB from P_BUS (APB_M0), the guard busy bits and the WDT request are synchronous
# to the root clock; so are the guard block bits and the cause enables.
# 10 ns outside the block on each side, as the template.
set_input_delay  10.0 -clock clk_cpu [get_ports {i_bus_apb_* i_guard_busy* i_wdt_rst_req}]
set_output_delay 10.0 -clock clk_cpu [get_ports {o_bus_apb_* o_guard_blk* o_cause_we_*}]
# o_clk_<d> are clocks; o_rst_n_<d> and o_rst_n_por are asynchronous resets
# released by a synchroniser on the destination clock (qnsc_rst_sync): no
# output delay on either.

# ---- 3. CDC constraints ------------------------------------------------------
# One clock: no crossing between clock domains. i_wdt_rst_req goes through
# qnsc_sync_cell (MAS 7.3) although it is synchronous, because it comes from a
# domain with a different reset.

# ---- 4. Reset (for RDC) ------------------------------------------------------
# PORSTN is asynchronous: glitch filter (qnsc_rst_filter, clockless) then
# qnsc_rst_sync. Nothing is timed from the pad.
set_false_path -from [get_ports i_rst_n_pad]
#   set_reset [get_ports i_rst_n_pad] -async -type reset -sense low
