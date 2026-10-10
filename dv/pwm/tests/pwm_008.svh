// PWM_008: an event fires on a rising edge of the selected channel only, is one
// i_clk_peri cycle wide, and never fires while EN[k] = 0.
task automatic count_events(input int unsigned k, input int unsigned len, output int unsigned n,
                            output int unsigned width_max);
  int unsigned w = 0;
  n = 0; width_max = 0;
  repeat (len) begin
    @(posedge r_clk);
    if (w_int_pwm[k]) begin
      w++;
      if (w == 1) n++;
      if (w > width_max) width_max = w;
    end else w = 0;
  end
endtask

task automatic pwm_008();
  int unsigned n, wmax;
  apb_write(C_CH_EN, 32'h1);
  timer_setup(0, 0, 99, 0);
  channel(0, 0, C_RSTSET, 30);                      // one rising edge per 100 cycles
  apb_write(C_CMD, C_START);
  repeat (300) @(posedge r_clk);
  apb_write(C_EVENT_CFG, 32'h0001_0000);            // line 0: SEL0 = channel 0, EN0 = 1
  repeat (5) @(posedge r_clk);
  count_events(0, 1000, n, wmax);
  if (n != 10 || wmax != 1) $fatal(1, "PWM_008: %0d events, widest %0d cycles; expected 10, 1", n, wmax);
  apb_write(C_EVENT_CFG, 32'h0000_0001);            // SEL0 = channel 1 (held 0), EN0 = 1
  count_events(0, 1000, n, wmax);
  if (n != 0) $fatal(1, "PWM_008: %0d events from a channel that never rises", n);
  apb_write(C_EVENT_CFG, 32'h0000_0000);            // SEL0 = channel 0, EN0 = 0
  count_events(0, 1000, n, wmax);
  if (n != 0 || w_int_pwm !== 4'h0) $fatal(1, "PWM_008: %0d events with EN0 = 0", n);
  $display("PWM_008 ok: 1-cycle event per rising edge, none from a static channel or with EN = 0");
endtask
