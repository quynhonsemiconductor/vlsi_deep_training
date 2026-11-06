// iomux_003 -- unassigned codes (b11 on every field, b10 outside PIN23-26): the
// pad has no driver and no receiver (OE = 0, IE = 0), and the IP input it would
// feed holds its idle value. All fields on b11, then each unassigned code of
// each field alone, then fully random selects (assigned and unassigned mixed).
t_set_all(2'b11);
t_check_all(4);
for (int f = 0; f < C_N_FIELD; f++)
  for (int unsigned c = f_max_code(f) + 1; c <= 3; c++) begin
    t_set_all(2'b00);
    t_set_field(f, 2'(c));
    t_check_all(2);
  end
repeat (40) begin
  i_iomux_sel = {12'($urandom), $urandom};
  t_check_all(2);
end
// by name: PIN11 (field 1) unassigned, pad low, UART0 RX still reads idle 1
t_set_all(2'b00);
t_set_field(1, 2'b11);
i_pad_in[6] = 1'b0; #1;
t_chk(o_pad_oe[6] === 1'b0 && o_pad_ie[6] === 1'b0 && o_uart_0_rx === 1'b1,
      "iomux_003: PIN11 b11 Hi-Z, UART0 RX idle 1");
t_set_all(2'b00);
$display("iomux_003 ok: unassigned codes give Hi-Z and idle IP inputs");
