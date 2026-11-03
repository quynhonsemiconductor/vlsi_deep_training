// iomux_001 -- after reset: PADSEL reads 0, every pad uses b00 (JTAG, UART0,
// I2C, GPIO), every unselected IP input holds its idle value.
t_expect32("iomux_001", A_PADSEL_0, 32'h0000_0000);
t_expect32("iomux_001", A_PADSEL_1, 32'h0000_0000);
t_check_all(8);
$display("iomux_001 ok: reset, every pad on b00, idle values");
