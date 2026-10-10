// PWM_001: ch_i_o[n] is channel n of timer i; o_pad_pwm[3:0] = ch_0_o, [7:4] = ch_1_o;
// timers 2 and 3 reach no pad.
task automatic pwm_001();
  apb_write(C_CH_EN, 32'hF);
  for (int m = 0; m < 4; m++) timer_setup(m, 0, 9, 0);
  for (int m = 0; m < 4; m++) begin
    for (int n = 0; n < 4; n++) begin
      for (int i = 0; i < 4; i++) apb_write(mod_base(i) + C_CMD, C_STOP | C_RST);
      for (int i = 0; i < 4; i++) for (int k = 0; k < 4; k++) channel(i, k, C_RST_MODE, 0);
      channel(m, n, 0, 0);                          // MODE 0 SET, TH 0: goes to 1 and stays
      for (int i = 0; i < 4; i++) apb_write(mod_base(i) + C_CMD, C_START);
      repeat (20) @(posedge r_clk);
      if (w_pad_pwm !== (m < 2 ? 8'(1 << (4 * m + n)) : 8'h00))
        $fatal(1, "PWM_001: timer %0d channel %0d gives o_pad_pwm = %08b", m, n, w_pad_pwm);
    end
  end
  $display("PWM_001 ok: o_pad_pwm[3:0] = ch_0_o, [7:4] = ch_1_o, timers 2, 3 on no pad");
endtask
