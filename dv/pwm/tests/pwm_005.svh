// PWM_005 (part): MODE 2 SETRST and MODE 6 RSTSET with SAW = 1. With the same TH
// they are complements; RSTSET is high TH + 1 cycles per period (measured, MAS 11).
// MODE 4 holds 0; MODE 0 with TH 0 goes to 1 and stays (the unconfigured-channel trap).
task automatic pwm_005();
  int unsigned high0, rises0, high1, rises1;
  apb_write(C_CH_EN, 32'h1);
  timer_setup(0, 0, 999, 0);
  channel(0, 0, C_RSTSET, 250);
  channel(0, 1, C_SETRST, 250);
  channel(0, 3, 0, 0);
  apb_write(C_CMD, C_START);
  repeat (2000) @(posedge r_clk);
  for (int i = 0; i < 3000; i++) begin
    @(posedge r_clk);
    if (w_pad_pwm[1] !== ~w_pad_pwm[0])
      $fatal(1, "PWM_005: SETRST and RSTSET with TH 250 are not complements (cycle %0d)", i);
    if (w_pad_pwm[2] !== 1'b0) $fatal(1, "PWM_005: MODE 4 channel not 0");
    if (w_pad_pwm[3] !== 1'b1) $fatal(1, "PWM_005: MODE 0 TH 0 channel not 1");
  end
  measure(0, 4000, high0, rises0);
  if (high0 != 4 * 251 || rises0 != 4)
    $fatal(1, "PWM_005: RSTSET TH 250 END 999 high %0d over 4 periods (%0d rises), expected 1004", high0, rises0);
  $display("PWM_005 ok: SETRST = ~RSTSET, RSTSET high TH + 1 = 251 of 1000 cycles");
endtask
