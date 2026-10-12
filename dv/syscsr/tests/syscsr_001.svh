// SYSCSR_001 After power-on: RESET_CAUSE = 0x1, CHIP_ID_REV = 0x5153_4F43, and
// DBG_BOOT = 0x0 with the DBG_EN pin at 0.
begin
  expect32("SYSCSR_001", A_RESET_CAUSE, 32'h0000_0001);
  expect32("SYSCSR_001", A_CHIP_ID_REV, CHIP_ID);
  expect32("SYSCSR_001", A_DBG_BOOT,    32'h0000_0000);
  $display("SYSCSR_001 ok: RESET_CAUSE 0x1, CHIP_ID_REV 0x51534F43, DBG_BOOT 0x0 after power-on");
end
