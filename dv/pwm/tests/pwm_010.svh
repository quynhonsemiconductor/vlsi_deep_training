// PWM_010: holes read 0 and ignore writes; the 1 KiB map repeats every 0x400 across the
// 16 KiB window (+0x400, +0x1000, +0x2000, +0x3C00 alias offset 0);
// PSLVERR = 0 and PREADY = 1 (checked on every read by apb_read).
task automatic pwm_010();
  apb_write(14'h030, 32'hFFFF_FFFF);
  expect_reg(14'h030, 32'h0, "PWM_010 hole M+0x30");
  apb_write(14'h108, 32'hFFFF_FFFF);
  expect_reg(14'h108, 32'h0, "PWM_010 hole 0x108");
  apb_write(14'h3FC, 32'hFFFF_FFFF);
  expect_reg(14'h3FC, 32'h0, "PWM_010 hole 0x3FC");
  apb_write(14'h40C, 32'h0005_0123);                // CH0_TH of timer 0 through the alias
  expect_reg(C_CH0_TH, 32'h0005_0123, "PWM_010 alias +0x400");
  expect_reg(14'hC0C, 32'h0005_0123, "PWM_010 alias +0xC00");
  expect_reg(14'h100C, 32'h0005_0123, "PWM_010 alias +0x1000");   // offset bit 12
  expect_reg(14'h200C, 32'h0005_0123, "PWM_010 alias +0x2000");   // offset bit 13
  expect_reg(14'h3C0C, 32'h0005_0123, "PWM_010 alias +0x3C00");   // the last 1 KiB of the 16 KiB window
  $display("PWM_010 ok: holes read 0, 1 KiB alias across the 16 KiB window, no error response");
endtask
