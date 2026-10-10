// PWM_010: holes read 0 and ignore writes; offset +0x400 aliases offset 0;
// PSLVERR = 0 and PREADY = 1 (checked on every read by apb_read).
task automatic pwm_010();
  apb_write(12'h030, 32'hFFFF_FFFF);
  expect_reg(12'h030, 32'h0, "PWM_010 hole M+0x30");
  apb_write(12'h108, 32'hFFFF_FFFF);
  expect_reg(12'h108, 32'h0, "PWM_010 hole 0x108");
  apb_write(12'h3FC, 32'hFFFF_FFFF);
  expect_reg(12'h3FC, 32'h0, "PWM_010 hole 0x3FC");
  apb_write(12'h40C, 32'h0005_0123);                // CH0_TH of timer 0 through the alias
  expect_reg(C_CH0_TH, 32'h0005_0123, "PWM_010 alias +0x400");
  expect_reg(12'hC0C, 32'h0005_0123, "PWM_010 alias +0xC00");
  $display("PWM_010 ok: holes read 0, 1 KiB alias, no error response");
endtask
