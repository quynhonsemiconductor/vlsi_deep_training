`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// m_qnsc_iomux -- the IO pin multiplexer of QSOC.
//
// In house (flow/lint/module_rules.yml lists iomux as an integration block).
// Spec: QNSC_IOMUX_MAS on the team SharePoint. Pin map: util/gen/iomux/
// iomux_pads.yml (Pad List v2), the one source of the two generated modules:
//
//   u_csr  m_qnsc_iomux_csr  APB slave, PADSEL_0 (0x0, pads 0-15) and
//                            PADSEL_1 (0x4, pads 16-27), 2 bits per pad,
//                            reset 0: b00 is JTAG + UART0, enough to boot
//   u_mux  m_qnsc_iomux_mux  combinational: per pad, the selected function
//                            drives o_pad_out/o_pad_oe and receives i_pad_in;
//                            an IP input no pad selects holds its idle value
//
// Here: the debug force. While i_dbg_en = 1 the five JTAG pads (pads 0-4,
// PIN5-9) use b00 whatever PADSEL holds, so software that remaps pins cannot
// cut off the debugger (QNSC_SYSDBG_MAS 7.1). PADSEL itself is not changed and
// reads back what software wrote.
//
// The pad cells are not here: o_pad_out / o_pad_oe / i_pad_in go to the pad
// ring in m_qnsc_chip (A / OE / Y of the pad cell, OE active high).
// -----------------------------------------------------------------------------
module m_qnsc_iomux (
  // ---- clock, reset: the peri cluster, as every APB slave -------------------
  input  logic        i_clk_peri,
  input  logic        i_rst_n_peri,

  // ---- APB slave (P_BUS) -----------------------------------------------------
  input  logic        i_bus_apb_psel,
  input  logic        i_bus_apb_penable,
  input  logic        i_bus_apb_pwrite,
  input  logic [13:0] i_bus_apb_paddr,      // contract: meta.apb_paddr_width
  input  logic [31:0] i_bus_apb_pwdata,
  input  logic [3:0]  i_bus_apb_pstrb,
  input  logic [2:0]  i_bus_apb_pprot,
  output logic [31:0] o_bus_apb_prdata,
  output logic        o_bus_apb_pready,
  output logic        o_bus_apb_pslverr,

  // ---- debug: o_dbg_en of SYSDBG, captured once after power-on ---------------
  input  logic        i_dbg_en,

  // ---- GPIO 0..2 (apb_gpio gpio_out / gpio_dir / gpio_in) -----------------------
  input  logic [7:0]  i_gpio_0_out,
  input  logic [7:0]  i_gpio_0_oe,
  output logic [7:0]  o_gpio_0_in,
  input  logic [7:0]  i_gpio_1_out,
  input  logic [7:0]  i_gpio_1_oe,
  output logic [7:0]  o_gpio_1_in,
  input  logic [7:0]  i_gpio_2_out,
  input  logic [7:0]  i_gpio_2_oe,
  output logic [7:0]  o_gpio_2_in,

  // ---- UART 0, 1 -------------------------------------------------------------
  input  logic        i_uart_0_tx,
  output logic        o_uart_0_rx,
  input  logic        i_uart_1_tx,
  output logic        o_uart_1_rx,

  // ---- SPI (host or device, chosen in the SPI wrapper) -----------------------
  input  logic        i_spi_sck,
  input  logic        i_spi_sck_oe,
  output logic        o_spi_sck,
  input  logic        i_spi_csb,
  input  logic        i_spi_csb_oe,
  output logic        o_spi_csb,
  input  logic [3:0]  i_spi_sd,
  input  logic [3:0]  i_spi_sd_oe,
  output logic [3:0]  o_spi_sd,

  // ---- I2C (open drain; OE active low, as apb_i2c drives it) ------------------
  input  logic        i_i2c_scl,
  input  logic        i_i2c_scl_oe_n,
  output logic        o_i2c_scl,
  input  logic        i_i2c_sda,
  input  logic        i_i2c_sda_oe_n,
  output logic        o_i2c_sda,

  // ---- PWM (apb_adv_timer, 8 channels) and its external inputs --------------
  input  logic [7:0]  i_pwm,
  output logic [3:0]  o_tim_ext,

  // ---- JTAG (SYSDBG TAP) -----------------------------------------------------
  output logic        o_jtag_tck,
  output logic        o_jtag_tms,
  output logic        o_jtag_tdi,
  input  logic        i_jtag_tdo,
  input  logic        i_jtag_tdo_oe,
  output logic        o_jtag_trst_n,

  // ---- pads: A, OE (active high), Y of the 28 muxed pad cells -----------------
  output logic [27:0] o_pad_out,
  output logic [27:0] o_pad_oe,
  input  logic [27:0] i_pad_in
);

logic [31:0] w_padsel_0;     // pads 0-15
logic [23:0] w_padsel_1;     // pads 16-27
logic [55:0] w_padsel_sw;    // as software wrote it
logic [55:0] w_padsel;       // as the mux uses it

// ---- registers ----------------------------------------------------------------
m_qnsc_iomux_csr u_csr (
  .i_bus_clk      (i_clk_peri),
  .i_bus_rstn     (i_rst_n_peri),
  .i_paddr        ({2'b00, i_bus_apb_paddr[13:0]}), // contract: meta.apb_paddr_width
  .i_protect_en   (1'b0),                       // PPROT connected, not checked
  .i_slverr_en    (1'b1),                       // misaligned address, partial PSTRB
  .i_pprot        (i_bus_apb_pprot),
  .i_pwdata       (i_bus_apb_pwdata),
  .i_pwrite       (i_bus_apb_pwrite),
  .i_penable      (i_bus_apb_penable),
  .i_psel         (i_bus_apb_psel),
  .i_pstrb        (i_bus_apb_pstrb),
  .o_pslverr      (o_bus_apb_pslverr),
  .o_pready       (o_bus_apb_pready),
  .o_prdata       (o_bus_apb_prdata),
  .o_padsel_0_sel (w_padsel_0),
  .o_padsel_1_sel (w_padsel_1)
);

assign w_padsel_sw = {w_padsel_1, w_padsel_0};

// ---- debug force: pads 0-4 (PIN5-9, TCK TMS TDI TDO TRSTN) to b00 ---------------
always_comb begin
  w_padsel = w_padsel_sw;
  if (i_dbg_en) begin
    w_padsel[9:0] = '0;
  end
end

// ---- datapath -------------------------------------------------------------------
m_qnsc_iomux_mux u_mux (
  .i_padsel       (w_padsel),
  .i_gpio_0_out   (i_gpio_0_out),
  .i_gpio_0_oe    (i_gpio_0_oe),
  .o_gpio_0_in    (o_gpio_0_in),
  .i_gpio_1_out   (i_gpio_1_out),
  .i_gpio_1_oe    (i_gpio_1_oe),
  .o_gpio_1_in    (o_gpio_1_in),
  .i_gpio_2_out   (i_gpio_2_out),
  .i_gpio_2_oe    (i_gpio_2_oe),
  .o_gpio_2_in    (o_gpio_2_in),
  .i_uart_0_tx    (i_uart_0_tx),
  .o_uart_0_rx    (o_uart_0_rx),
  .i_uart_1_tx    (i_uart_1_tx),
  .o_uart_1_rx    (o_uart_1_rx),
  .i_spi_sck      (i_spi_sck),
  .i_spi_sck_oe   (i_spi_sck_oe),
  .o_spi_sck      (o_spi_sck),
  .i_spi_csb      (i_spi_csb),
  .i_spi_csb_oe   (i_spi_csb_oe),
  .o_spi_csb      (o_spi_csb),
  .i_spi_sd       (i_spi_sd),
  .i_spi_sd_oe    (i_spi_sd_oe),
  .o_spi_sd       (o_spi_sd),
  .i_i2c_scl      (i_i2c_scl),
  .i_i2c_scl_oe_n (i_i2c_scl_oe_n),
  .o_i2c_scl      (o_i2c_scl),
  .i_i2c_sda      (i_i2c_sda),
  .i_i2c_sda_oe_n (i_i2c_sda_oe_n),
  .o_i2c_sda      (o_i2c_sda),
  .i_pwm          (i_pwm),
  .o_tim_ext      (o_tim_ext),
  .o_jtag_tck     (o_jtag_tck),
  .o_jtag_tms     (o_jtag_tms),
  .o_jtag_tdi     (o_jtag_tdi),
  .i_jtag_tdo     (i_jtag_tdo),
  .i_jtag_tdo_oe  (i_jtag_tdo_oe),
  .o_jtag_trst_n  (o_jtag_trst_n),
  .o_pad_out      (o_pad_out),
  .o_pad_oe       (o_pad_oe),
  .i_pad_in       (i_pad_in)
);

endmodule
