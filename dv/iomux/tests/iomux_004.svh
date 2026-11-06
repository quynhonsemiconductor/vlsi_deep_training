// iomux_004 -- fixed pads and pad controls, by name: I2C is open drain (A = the
// wrapper's 0, OE = its active-high enable), a TDO pad and an output-only pad
// have IE = 0, an input-only pad has OE = 0. Checked directly here, not through
// the generated table, so a table error that the generator accepts is caught.
t_set_all(1'b0);
#1;
i_i2c_scl = 1'b0; i_i2c_scl_oe = 1'b1; i_i2c_sda = 1'b0; i_i2c_sda_oe = 1'b0;
i_pad_in = '0;
#1;
t_chk(o_pad_out[14] === 1'b0 && o_pad_oe[14] === 1'b1, "iomux_004: PIN21 SCL pulls low");
t_chk(o_pad_oe[15] === 1'b0, "iomux_004: PIN22 SDA released");
t_chk(o_pad_ie[14] && o_pad_ie[15], "iomux_004: I2C pads IE = 1");
t_chk(o_i2c_scl === 1'b0, "iomux_004: SCL reads the pad");
t_chk(o_pad_ie[3] === 1'b0, "iomux_004: PIN8 TDO is output only, IE = 0");
// PIN33 fixed TIM_EXT0: input only, reaches the PWM wrapper
i_pad_in[24] = 1'b1; #1;
t_chk(o_pad_oe[24] === 1'b0 && o_pad_ie[24] === 1'b1 && o_tim_ext[0] === 1'b1,
      "iomux_004: PIN33 TIM_EXT0 input");
i_pad_in[24] = 1'b0;
// PIN12 b1 reserved: no driver, no receiver. UART1 on PIN19/20 b1: RX holds idle 1 until selected, TX has OE = 1
i_pad_in[13] = 1'b0; #1;
t_chk(o_uart_1_rx === 1'b1, "iomux_004: UART1 RX idle 1 while PIN20 is on b0");
i_iomux_sel = (24'b1 << 7) | (24'b1 << 12) | (24'b1 << 13); i_uart_1_tx = 1'b0; #1;
t_chk(o_pad_oe[7] === 1'b0 && o_pad_ie[7] === 1'b0, "iomux_004: PIN12 b1 reserved, Hi-Z");
t_chk(o_pad_out[12] === 1'b0 && o_pad_oe[12] === 1'b1 && o_pad_ie[12] === 1'b0,
      "iomux_004: PIN19 UART1_TX, OE = 1, IE = 0");
t_chk(o_pad_oe[13] === 1'b0 && o_pad_ie[13] === 1'b1, "iomux_004: PIN20 UART1_RX input");
t_chk(o_uart_1_rx === 1'b0, "iomux_004: PIN20 reaches UART1 RX");
i_iomux_sel = 24'b1 << 14; #1;
t_chk(o_pad_oe[16] === 1'b1 && o_pad_ie[16] === 1'b0, "iomux_004: PIN23 PWM_0 OE = 1, IE = 0");
t_set_all(1'b0);
$display("iomux_004 ok: I2C open drain, IE of output-only pads, UART1 PIN19/20, PIN12 b1 reserved, TIM_EXT0 PIN33");
