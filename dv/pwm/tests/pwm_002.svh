// PWM_002: every register resets to the value of MAS section 6; CMD reads 0.
task automatic pwm_002();
  for (int m = 0; m < 4; m++) begin
    expect_reg(mod_base(m) + C_CMD, 32'h0, "PWM_002 CMD");
    expect_reg(mod_base(m) + C_CFG, 32'h0000_1000, "PWM_002 CFG (SAW = 1)");
    expect_reg(mod_base(m) + C_TH, 32'h0, "PWM_002 TH");
    for (int n = 0; n < 4; n++) begin
      expect_reg(mod_base(m) + C_CH0_TH + 12'(4 * n), 32'h0, "PWM_002 CHn_TH");
      expect_reg(mod_base(m) + C_CH0_LUT + 12'(4 * n), 32'h0, "PWM_002 CHn_LUT");
    end
    expect_reg(mod_base(m) + C_COUNTER, 32'h0, "PWM_002 COUNTER");
  end
  expect_reg(C_EVENT_CFG, 32'h0, "PWM_002 EVENT_CFG");
  expect_reg(C_CH_EN, 32'h0, "PWM_002 CH_EN");
  if (w_pad_pwm !== 8'h00 || w_int_pwm !== 4'h0)
    $fatal(1, "PWM_002: outputs not 0 in reset: pad %08b int %04b", w_pad_pwm, w_int_pwm);
  $display("PWM_002 ok: reset values, outputs 0");
endtask
