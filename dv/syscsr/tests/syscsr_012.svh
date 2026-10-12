// SYSCSR_012 With dbg_en_mask = 1, DBG_BOOT.dbg_en reads 0 whatever the pin;
// writing dbg_en_mask = 0 shows the pin again.
begin
  wr32(A_DBG_BOOT, 32'h0000_0002);                 // the host lets the ROM go
  expect32("SYSCSR_012", A_DBG_BOOT, 32'h0000_0002);
  pin_to("SYSCSR_012", 1'b0);
  expect32("SYSCSR_012", A_DBG_BOOT, 32'h0000_0002);
  pin_to("SYSCSR_012", 1'b1);
  expect32("SYSCSR_012", A_DBG_BOOT, 32'h0000_0002);
  wr32(A_DBG_BOOT, 32'h0000_0000);
  expect32("SYSCSR_012", A_DBG_BOOT, 32'h0000_0001);
  $display("SYSCSR_012 ok: dbg_en_mask = 1 forces dbg_en to 0 with the pin at 0 or 1; 0 shows the pin");
end
