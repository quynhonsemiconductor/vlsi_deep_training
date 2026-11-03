// iomux_002 -- every pad under every code: A and OE come from the selected
// function, Y reaches it, an unassigned code leaves OE = 0, and every IP input
// no pad selects holds its idle value. Then random mixes of codes.
for (int unsigned c = 0; c < 4; c++) begin
  t_set_all(2'(c));
  t_check_all(8);
end
repeat (20) begin
  for (int k = 0; k < C_N_PAD; k++) r_sel_sw[k] = 2'($urandom);
  t_write_sel();
  t_check_all(4);
end
$display("iomux_002 ok: every pad x every code, and random mixes");
