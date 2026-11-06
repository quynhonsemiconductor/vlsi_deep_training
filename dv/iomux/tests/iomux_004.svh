// iomux_004 -- pads and pad controls by name: I2C is open drain (A = the
// wrapper's 0, OE = its active-high enable), output-only pads have IE = 0,
// input-only pads have OE = 0, SPID on PIN23-26 b10. Checked directly here, not
// through the generated table, so a table error that the generator accepts is
// caught.
t_set_all(2'b00);
#1;
i_i2c_scl = 1'b0; i_i2c_scl_oe = 1'b1; i_i2c_sda = 1'b0; i_i2c_sda_oe = 1'b0;
i_pad_in = '0;
#1;
t_chk(o_pad_out[14] === 1'b0 && o_pad_oe[14] === 1'b1, "iomux_004: PIN21 SCL pulls low");
t_chk(o_pad_oe[15] === 1'b0, "iomux_004: PIN22 SDA released");
t_chk(o_pad_ie[14] && o_pad_ie[15], "iomux_004: I2C pads IE = 1");
t_chk(o_i2c_scl === 1'b0, "iomux_004: SCL reads the pad");
t_chk(o_pad_ie[3] === 1'b0, "iomux_004: PIN8 TDO is output only, IE = 0");
// PIN33 b00 TIM_EXT0: input only, reaches the PWM wrapper
i_pad_in[24] = 1'b1; #1;
t_chk(o_pad_oe[24] === 1'b0 && o_pad_ie[24] === 1'b1 && o_tim_ext[0] === 1'b1,
      "iomux_004: PIN33 TIM_EXT0 input");
i_pad_in[24] = 1'b0;
// UART1 on PIN19/20 b01: RX holds idle 1 until selected, TX has OE = 1
i_pad_in[13] = 1'b0; #1;
t_chk(o_uart_1_rx === 1'b1, "iomux_004: UART1 RX idle 1 while PIN20 is on b00");
t_set_field(6, 2'b01); t_set_field(7, 2'b01); i_uart_1_tx = 1'b0; #1;
t_chk(o_pad_out[12] === 1'b0 && o_pad_oe[12] === 1'b1 && o_pad_ie[12] === 1'b0,
      "iomux_004: PIN19 UART1_TX, OE = 1, IE = 0");
t_chk(o_pad_oe[13] === 1'b0 && o_pad_ie[13] === 1'b1, "iomux_004: PIN20 UART1_RX input");
t_chk(o_uart_1_rx === 1'b0, "iomux_004: PIN20 reaches UART1 RX");
// PWM_0 on PIN23 b01: output only
t_set_all(2'b00); t_set_field(10, 2'b01); #1;
t_chk(o_pad_oe[16] === 1'b1 && o_pad_ie[16] === 1'b0, "iomux_004: PIN23 PWM_0 OE = 1, IE = 0");
// SPID on PIN23-26 b10: SCK, CSB, MOSI inputs; MISO output with its enable
for (int f = 10; f <= 13; f++) t_set_field(f, 2'b10);
i_pad_in[16] = 1'b1; i_pad_in[17] = 1'b0; i_pad_in[18] = 1'b1;
i_spid_miso = 1'b1; i_spid_miso_oe = 1'b1; #1;
t_chk(o_pad_oe[16] === 1'b0 && o_pad_ie[16] === 1'b1 && o_spid_sck === 1'b1,
      "iomux_004: PIN23 SPID_SCK input");
t_chk(o_pad_oe[17] === 1'b0 && o_pad_ie[17] === 1'b1 && o_spid_csb === 1'b0,
      "iomux_004: PIN24 SPID_CSB input");
t_chk(o_pad_oe[18] === 1'b0 && o_pad_ie[18] === 1'b1 && o_spid_mosi === 1'b1,
      "iomux_004: PIN25 SPID_MOSI input");
t_chk(o_pad_out[19] === 1'b1 && o_pad_oe[19] === 1'b1 && o_pad_ie[19] === 1'b0,
      "iomux_004: PIN26 SPID_MISO output");
i_spid_miso_oe = 1'b0; #1;
t_chk(o_pad_oe[19] === 1'b0, "iomux_004: PIN26 SPID_MISO OE follows i_spid_miso_oe");
t_set_all(2'b00); #1;
t_chk(o_spid_csb === 1'b1, "iomux_004: SPID CSB idle 1 when PIN24 leaves b10");
$display("iomux_004 ok: I2C open drain, IE of output-only pads, UART1 PIN19/20, TIM_EXT0 PIN33, SPID PIN23-26");
