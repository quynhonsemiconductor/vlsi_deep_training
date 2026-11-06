// iomux_001 -- IOMUX_SEL = 0 (its reset value in SYSCSR): every muxed pad uses
// b0 (JTAG, UART0, GPIO), every fixed pad its one function, every unselected IP
// input holds its idle value.
t_set_all(1'b0);
t_check_all(8);
$display("iomux_001 ok: IOMUX_SEL = 0, every pad on b0, idle values");
