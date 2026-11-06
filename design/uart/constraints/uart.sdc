# =============================================================================
# SDC of the uart block (m_qnsc_wrap_uart), from flow/sdc_template.sdc.
# Constrains the block for SYN (DC), CDC/RDC (VC Static) and STA (PT).
# =============================================================================

# ---- 1. Clock ---------------------------------------------------------------
# One clock for the whole chip: 20 MHz, 50% duty. The block runs on the peri
# cluster (contract clock_domains.peri).
create_clock -name clk -period 50.0 [get_ports i_clk_peri]
set_clock_uncertainty -setup 0.5 [get_clocks clk]

# ---- 2. Input / Output delays ------------------------------------------------
set_input_delay  10.0 -clock clk [remove_from_collection [all_inputs] [get_ports {i_clk_peri i_rst_n_peri}]]
set_output_delay 10.0 -clock clk [all_outputs]

# ---- 3. CDC constraints ------------------------------------------------------
# RX comes from the pad, asynchronous to clk. obi_uart_rx captures it in the
# 2-stage common_cells sync (i_sync, obi_uart_rx.sv:132) before any logic uses it.
set_false_path -from [get_ports i_pad_uart_rx] -to [get_clocks clk]

# ---- 4. Reset (for RDC) ------------------------------------------------------
# i_rst_n_peri is asynchronous, active low; its release is synchronised by SCRC.
#   set_reset [get_ports i_rst_n_peri] -async -type reset -sense low
