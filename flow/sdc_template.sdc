# =============================================================================
# SDC template for a QSOC block. Copy to <block>.sdc and fill in the values.
# This file constrains the block for SYN (DC), CDC/RDC (VC Static) and STA (PT).
#
# The clock and reset names follow the contract (clock_domains clusters);
# the port names follow the block's MAS section 5.
# =============================================================================

# ---- 1. Clock ---------------------------------------------------------------
# One clock for the whole chip: 20 MHz, 50% duty.
# Replace i_clk_<cluster> with the block's clock port (MAS 5).
create_clock -name clk -period 50.0 [get_ports i_clk_peri]

# Clock uncertainty (setup guard) — adjust per block after first SYN run.
set_clock_uncertainty -setup 0.5 [get_clocks clk]

# ---- 2. Input / Output delays ------------------------------------------------
# External world: assume 10 ns available outside the block on both sides
# (conservative for a 50 ns period; tighten after top-level STA).
set_input_delay  10.0 -clock clk [remove_from_collection [all_inputs] [get_ports i_clk_peri]]
set_output_delay 10.0 -clock clk [all_outputs]

# ---- 3. CDC constraints (for VC Static CDC / RDC) ----------------------------
# Every crossing through a shared cell (qnsc_sync) is declared here so the
# tool knows it is intentional. The cell handles the synchronisation; the
# constraint tells the analyser to treat the destination as stable.
#
# Example for PWM (TIM_EXT pads through qnsc_sync):
#   set_false_path -from [get_ports i_pad_tim_ext*] -to [get_clocks clk]
#   set_max_delay 50.0 -from [get_ports i_pad_tim_ext*] -to [get_clocks clk]
set_false_path -from [get_ports i_pad_tim_ext*] -to [get_clocks clk]

# ---- 4. Reset (for RDC) ------------------------------------------------------
# Declare the async reset so RDC knows it is asynchronous and can check
# the release synchroniser.
#   set_reset [get_ports i_rst_n_peri] -async -type reset -sense low
