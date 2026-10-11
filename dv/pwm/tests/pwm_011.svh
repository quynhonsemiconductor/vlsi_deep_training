// PWM_011: when a new value takes effect (MAS 7.8). Marker: channel 1 is RSTSET with
// TH 0, so its rising edge is the end of a period (counter back at START).
//   TH (START, END, SAW)  only at CMD.START, or at CMD.UPDATE; while stopped at once,
//                         while running at the end of the period in progress
//   CHn_TH, MODE, PRESC   within a few cycles, in the period in progress
//   IN_SEL, IN_MODE       within a few cycles
task automatic wait_rise(input int unsigned b, output int unsigned stamp);
  logic prev = w_pad_pwm[b];
  forever begin
    @(posedge r_clk);
    if (w_pad_pwm[b] && !prev) begin stamp = r_cycle; return; end
    prev = w_pad_pwm[b];
  end
endtask

// stop and clear timer 0, then run it START..END, PRESC, with the marker on channel 1
task automatic restart_timer(input int unsigned start, input int unsigned stop,
                             input int unsigned presc);
  apb_write(C_CMD, C_STOP | C_RST);
  timer_setup(0, start, stop, presc);
  channel(0, 1, C_RSTSET, 0);
endtask

task automatic pwm_011();
  int unsigned m0, m1, m2, m3, p, i;
  logic [31:0] c0, c1;

  apb_write(C_CH_EN, 32'h1);

  // --- TH written while running: no effect without CMD.UPDATE
  restart_timer(0, 99, 0);
  apb_write(C_CMD, C_START);
  wait_rise(1, m0);
  apb_write(mod_base(0) + C_TH, (32'd199 << 16));
  wait_rise(1, m1); wait_rise(1, m2); wait_rise(1, m3);
  if (m1 - m0 != 100 || m2 - m1 != 100 || m3 - m2 != 100)
    $fatal(1, "PWM_011: END written without UPDATE changed the period: %0d %0d %0d, expected 100",
           m1 - m0, m2 - m1, m3 - m2);

  // --- CMD.UPDATE while running: the period in progress ends at its old length
  wait_rise(1, m0);
  repeat (40) @(posedge r_clk);
  apb_write(C_CMD, C_UPDATE);
  wait_rise(1, m1); wait_rise(1, m2); wait_rise(1, m3);
  if (m1 - m0 != 100) $fatal(1, "PWM_011: period in progress at UPDATE lasted %0d, expected 100 (old END)", m1 - m0);
  if (m2 - m1 != 200 || m3 - m2 != 200)
    $fatal(1, "PWM_011: periods after UPDATE %0d, %0d, expected 200 (new END)", m2 - m1, m3 - m2);

  // --- CMD.UPDATE while stopped: the counter loads START at once; TH alone does not
  restart_timer(0, 99, 0);
  apb_write(mod_base(0) + C_TH, (32'd50 << 16) | 32'd5);
  expect_reg(mod_base(0) + 12'h02C, 32'd0, "PWM_011: COUNTER after a TH write, stopped");
  apb_write(C_CMD, C_UPDATE);
  expect_reg(mod_base(0) + 12'h02C, 32'd5, "PWM_011: COUNTER after UPDATE, stopped");

  // --- CMD.START loads TH: a period of END - START + 1 = 46
  channel(0, 1, C_RSTSET, 5);              // the marker needs TH >= START to match
  apb_write(C_CMD, C_START);
  wait_rise(1, m0); wait_rise(1, m1); wait_rise(1, m2);
  if (m1 - m0 != 46 || m2 - m1 != 46)
    $fatal(1, "PWM_011: periods after START with TH 5..50: %0d, %0d, expected 46", m1 - m0, m2 - m1);

  // --- CHn_TH lowered below the counter while running: the match is missed, the
  //     output stays high to the end of the period and through the next one
  restart_timer(0, 99, 0);
  channel(0, 0, C_RSTSET, 70);
  apb_write(C_CMD, C_START);
  wait_rise(1, m0);
  repeat (50) @(posedge r_clk);
  channel(0, 0, C_RSTSET, 10);
  p = r_cycle;
  wait_rise(1, m1);                       // end of the period in progress
  while (w_pad_pwm[0]) @(posedge r_clk);
  i = r_cycle - p;
  if (m1 < p || i < 55 || i > 75)
    $fatal(1, "PWM_011: TH 70 -> 10 at counter ~50: output fell %0d cycles after the write, expected 55..75 (next period)", i);

  // --- CHn_TH raised before its match while running: the new match is used in the
  //     same period
  restart_timer(0, 99, 0);
  channel(0, 0, C_SETRST, 10);
  apb_write(C_CMD, C_START);
  wait_rise(1, m0);
  repeat (2) @(posedge r_clk);
  channel(0, 0, C_SETRST, 80);
  while (!w_pad_pwm[0]) @(posedge r_clk);
  i = r_cycle - m0;
  if (i < 78 || i > 84)
    $fatal(1, "PWM_011: TH 10 -> 80 at counter ~3: output rose %0d cycles after the period start, expected 78..84", i);

  // --- PRESC written while running: used in the period in progress, no UPDATE needed
  restart_timer(0, 99, 0);
  apb_write(C_CMD, C_START);
  wait_rise(1, m0);
  repeat (30) @(posedge r_clk);
  apb_write(mod_base(0) + C_CFG, (32'd1 << 16) | (32'd1 << 12));   // PRESC 1, SAW 1
  wait_rise(1, m1); wait_rise(1, m2);
  if (m1 - m0 < 160 || m1 - m0 > 180 || m2 - m1 != 200)
    $fatal(1, "PWM_011: PRESC 0 -> 1 at counter ~30: periods %0d, %0d, expected 160..180 then 200", m1 - m0, m2 - m1);

  // --- IN_MODE and IN_SEL written while running: the counter stops within a few cycles
  //     (IN_SEL 4 is constant 0, IN_MODE 2 counts while the signal is 1)
  restart_timer(0, 99, 0);
  apb_write(C_CMD, C_START);
  repeat (20) @(posedge r_clk);
  apb_write(mod_base(0) + C_CFG, (32'd2 << 8) | (32'd1 << 12) | 32'd4);
  repeat (10) @(posedge r_clk);
  apb_read(mod_base(0) + 12'h02C, c0);
  repeat (30) @(posedge r_clk);
  apb_read(mod_base(0) + 12'h02C, c1);
  if (c0 !== c1) $fatal(1, "PWM_011: COUNTER moved after IN_MODE 2 / IN_SEL 4 were written: %0d -> %0d", c0, c1);

  $display("PWM_011 ok: TH only at START or UPDATE (running: at period end; stopped: at once); CHn_TH, MODE, PRESC, IN_SEL, IN_MODE within the period in progress");
endtask
