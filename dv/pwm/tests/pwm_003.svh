// PWM_003: out of reset, CMD.START has no effect until CH_EN[i] = 1.
task automatic pwm_003();
  timer_setup(0, 0, 9, 0);
  channel(0, 0, 0, 0);                              // would go to 1 at the first count
  apb_write(C_CMD, C_START);
  repeat (50) @(posedge r_clk);
  if (w_pad_pwm[0] !== 1'b0) $fatal(1, "PWM_003: timer 0 ran with CH_EN = 0");
  expect_reg(C_COUNTER, 32'h0, "PWM_003 COUNTER with CH_EN = 0");
  apb_write(C_CH_EN, 32'h1);
  repeat (50) @(posedge r_clk);
  if (w_pad_pwm[0] !== 1'b0) $fatal(1, "PWM_003: a START written while CH_EN = 0 took effect later");
  apb_write(C_CMD, C_START);
  repeat (50) @(posedge r_clk);
  if (w_pad_pwm[0] !== 1'b1) $fatal(1, "PWM_003: START with CH_EN = 1 did not run timer 0");
  $display("PWM_003 ok: START ignored while CH_EN = 0");
endtask
