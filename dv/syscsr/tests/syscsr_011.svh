// SYSCSR_011 With dbg_en_mask = 0, DBG_BOOT.dbg_en follows the DBG_EN pin two
// clock edges later, rising and falling.
begin
  pin_to("SYSCSR_011", 1'b1);
  expect32("SYSCSR_011", A_DBG_BOOT, 32'h0000_0001);
  pin_to("SYSCSR_011", 1'b0);
  expect32("SYSCSR_011", A_DBG_BOOT, 32'h0000_0000);
  pin_to("SYSCSR_011", 1'b1);
  expect32("SYSCSR_011", A_DBG_BOOT, 32'h0000_0001);
  $display("SYSCSR_011 ok: dbg_en follows the DBG_EN pin after two edges, up and down");
end
