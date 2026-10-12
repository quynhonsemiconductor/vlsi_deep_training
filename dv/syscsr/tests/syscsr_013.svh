// SYSCSR_013 A write to DBG_BOOT cannot set dbg_en: bit 0 is read-only and
// bits 31:2 read 0.
begin
  pin_to("SYSCSR_013", 1'b0);
  wr32(A_DBG_BOOT, 32'hFFFF_FFFD);                 // every bit but the mask
  expect32("SYSCSR_013", A_DBG_BOOT, 32'h0000_0000);
  wr32(A_DBG_BOOT, 32'hFFFF_FFFF);
  expect32("SYSCSR_013", A_DBG_BOOT, 32'h0000_0002);
  wr32(A_DBG_BOOT, 32'h0000_0000);
  $display("SYSCSR_013 ok: writes cannot set dbg_en; bits 31:2 read 0");
end
