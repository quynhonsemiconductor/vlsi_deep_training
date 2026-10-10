// PWM_004: SAW = 1 period (END - START + 1) x (PRESC + 1); SAW = 0 period
// 2 x (END - START) x (PRESC + 1). Measured between rising edges of channel 0.
task automatic period_case(input int unsigned start, input int unsigned stop, input int unsigned presc,
                           input bit saw, input int unsigned exp);
  int unsigned t0, t1, cyc;
  logic prev;
  apb_write(C_CMD, C_STOP | C_RST);
  timer_setup(0, start, stop, presc, saw);
  channel(0, 0, C_SETRST, start + (stop - start) / 2);
  apb_write(C_CMD, C_START);
  repeat (3 * exp) @(posedge r_clk);                // settle
  cyc = 0; t0 = 0; t1 = 0; prev = w_pad_pwm[0];
  while (t1 == 0 && cyc < 10 * exp) begin
    @(posedge r_clk); cyc++;
    if (w_pad_pwm[0] && !prev) begin
      if (t0 == 0) t0 = cyc; else t1 = cyc;
    end
    prev = w_pad_pwm[0];
  end
  if (t1 - t0 != exp)
    $fatal(1, "PWM_004: START %0d END %0d PRESC %0d SAW %0d: period %0d, expected %0d",
           start, stop, presc, saw, t1 - t0, exp);
endtask

task automatic pwm_004();
  apb_write(C_CH_EN, 32'h1);
  period_case(0, 99, 0, 1'b1, 100);
  period_case(0, 99, 3, 1'b1, 400);
  period_case(10, 59, 1, 1'b1, 100);
  period_case(0, 50, 0, 1'b0, 100);
  period_case(20, 45, 2, 1'b0, 150);
  $display("PWM_004 ok: SAW = 1 and SAW = 0 periods");
endtask
