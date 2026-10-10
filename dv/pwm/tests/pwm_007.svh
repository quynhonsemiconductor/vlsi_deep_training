// PWM_007: CMD.STOP holds all four outputs; CMD = STOP | RST drives them to 0.
task automatic pwm_007();
  logic [3:0] held;
  apb_write(C_CH_EN, 32'h1);
  timer_setup(0, 0, 99, 0);
  channel(0, 0, C_RSTSET, 30);
  channel(0, 1, 0, 0);                              // goes to 1 and stays
  apb_write(C_CMD, C_START);
  wait (w_pad_pwm[0] === 1'b1);
  repeat (5) @(posedge r_clk);
  apb_write(C_CMD, C_STOP);
  repeat (2) @(posedge r_clk);
  held = w_pad_pwm[3:0];
  repeat (300) begin
    @(posedge r_clk);
    if (w_pad_pwm[3:0] !== held) $fatal(1, "PWM_007: outputs moved after STOP: %04b -> %04b", held, w_pad_pwm[3:0]);
  end
  if (held[1] !== 1'b1) $fatal(1, "PWM_007: test did not hold a 1 (held %04b)", held);
  apb_write(C_CMD, C_STOP | C_RST);
  repeat (3) @(posedge r_clk);
  if (w_pad_pwm[3:0] !== 4'h0) $fatal(1, "PWM_007: STOP | RST left outputs %04b", w_pad_pwm[3:0]);
  $display("PWM_007 ok: STOP holds %04b, STOP | RST drives 0", held);
endtask
