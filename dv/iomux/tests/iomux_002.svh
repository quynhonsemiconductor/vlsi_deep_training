// iomux_002 -- every pad under every assigned code: A, OE and IE come from the
// selected function, Y reaches it, and every IP input no pad selects holds its
// idle value. All fields on b01, then b10 on PIN23-26 (SPID), then each field
// alone on each assigned code, then random mixes of assigned codes.
t_set_all(2'b01);
t_check_all(8);
for (int f = 10; f <= 13; f++) t_set_field(f, 2'b10);
t_check_all(8);
for (int f = 0; f < C_N_FIELD; f++)
  for (int unsigned c = 1; c <= f_max_code(f); c++) begin
    t_set_all(2'b00);
    t_set_field(f, 2'(c));
    t_check_all(2);
  end
repeat (40) begin
  t_set_random_valid();
  t_check_all(2);
end
t_set_all(2'b00);
$display("iomux_002 ok: every assigned code of every pad, one field at a time and random mixes");
