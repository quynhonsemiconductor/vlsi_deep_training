// PWM_009 (part): IN_MODE 3 counts rising edges of TIM_EXTn (IN_SEL n) through the
// wrapper's synchroniser; IN_MODE 0 counts every cycle.
task automatic tim_ext_pulses(input int unsigned pin, input int unsigned count);
  repeat (count) begin
    r_tim_ext[pin] = 1'b1; repeat (3) @(posedge r_clk);
    r_tim_ext[pin] = 1'b0; repeat (3) @(posedge r_clk);
  end
endtask

task automatic pwm_009();
  logic [31:0] c;
  apb_write(C_CH_EN, 32'h1);
  for (int unsigned pin = 0; pin < 4; pin++) begin
    apb_write(C_CMD, C_STOP | C_RST);
    apb_write(C_TH, 32'd1000 << 16);
    apb_write(C_CFG, (32'd1 << 12) | (32'd3 << 8) | 32'(pin));   // SAW, IN_MODE 3, IN_SEL pin
    apb_write(C_CMD, C_START);
    repeat (10) @(posedge r_clk);
    tim_ext_pulses(pin, 7);
    repeat (10) @(posedge r_clk);
    apb_read(C_COUNTER, c);
    if (c != 7) $fatal(1, "PWM_009: TIM_EXT%0d, 7 rising edges, COUNTER = %0d", pin, c);
    tim_ext_pulses((pin + 1) % 4, 5);                            // another pin: not counted
    repeat (10) @(posedge r_clk);
    apb_read(C_COUNTER, c);
    if (c != 7) $fatal(1, "PWM_009: IN_SEL %0d counted TIM_EXT%0d (COUNTER = %0d)", pin, (pin + 1) % 4, c);
  end
  $display("PWM_009 ok: IN_MODE 3 counts the rising edges of the selected TIM_EXT pin only");
endtask
