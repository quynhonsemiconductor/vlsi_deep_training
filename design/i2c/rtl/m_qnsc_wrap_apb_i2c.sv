// QNSC wrapper of pulp-platform/apb_i2c for the QSOC peripheral bus.
//
// The core is vendored at vendor/pulp-platform/apb_i2c with
// vendor/patches/pulp-platform_apb_i2c/ applied, which adds the DMA request
// lines and the REG_TXCMD / REG_RXCMD registers. This wrapper maps the core
// onto QSOC port names and hands the pad signals to IOMUX as
// input / output / output-enable, so the tri-state lives in the pad ring --
// the same split SYSDBG uses for tdo_oe_o.
//
// Naming follows QNSC RTL Design Naming Rule V1.0.

import qnsc_pkg::*;

module m_qnsc_wrap_apb_i2c #(
  // APB address width. One width for every peripheral slave is still tbd: in
  // util/qsoc_contract.yml (bus owner); until then it covers the 16 KiB window.
  // The core decodes only PADDR[5:2], so the window aliases every 64 bytes.
  parameter int unsigned P_APB_ADDR_WIDTH = $clog2(C_I2C_SIZE)  // naming-check: ignore -- $clog2 is a system function
) (
  // Clock and reset, peri cluster (gateable by SCRC CLK_EN)
  input  logic                        i_clk_peri,
  input  logic                        i_rst_n_peri,

  // APB slave (P_BUS, APB_M12)
  input  logic [P_APB_ADDR_WIDTH-1:0] i_bus_apb_paddr,
  input  logic [31:0]                 i_bus_apb_pwdata,
  input  logic                        i_bus_apb_pwrite,
  input  logic                        i_bus_apb_psel,
  input  logic                        i_bus_apb_penable,
  output logic [31:0]                 o_bus_apb_prdata,
  output logic                        o_bus_apb_pready,
  output logic                        o_bus_apb_pslverr,

  // Interrupt to INTMAP (fast line C_INT_LINE_I2C, level)
  output logic                        o_int_i2c,

  // DMA handshake (QSOC peripheral-triggered DMA channel)
  output logic                        o_dma_tx_req,
  output logic                        o_dma_rx_req,
  input  logic                        i_dma_last,

  // I2C pins towards IOMUX. Open drain: the core only ever drives 0, so the
  // output enable alone decides between pulling low and releasing the line.
  input  logic                        i_gpio_i2c_scl,
  output logic                        o_gpio_i2c_scl,
  output logic                        o_gpio_i2c_scl_oe,
  input  logic                        i_gpio_i2c_sda,
  output logic                        o_gpio_i2c_sda,
  output logic                        o_gpio_i2c_sda_oe
);

  logic w_scl_padoen;  // active low in the core: 0 = drive
  logic w_sda_padoen;

  apb_i2c #(
    .APB_ADDR_WIDTH ( P_APB_ADDR_WIDTH )
  ) u_i2c (
    .HCLK         ( i_clk_peri        ),
    .HRESETn      ( i_rst_n_peri      ),
    .PADDR        ( i_bus_apb_paddr   ),
    .PWDATA       ( i_bus_apb_pwdata  ),
    .PWRITE       ( i_bus_apb_pwrite  ),
    .PSEL         ( i_bus_apb_psel    ),
    .PENABLE      ( i_bus_apb_penable ),
    .PRDATA       ( o_bus_apb_prdata  ),
    .PREADY       ( o_bus_apb_pready  ),
    .PSLVERR      ( o_bus_apb_pslverr ),
    .interrupt_o  ( o_int_i2c         ),
    .dma_tx_req_o ( o_dma_tx_req      ),
    .dma_rx_req_o ( o_dma_rx_req      ),
    .dma_last_i   ( i_dma_last        ),
    .scl_pad_i    ( i_gpio_i2c_scl    ),
    .scl_pad_o    ( o_gpio_i2c_scl    ),
    .scl_padoen_o ( w_scl_padoen      ),
    .sda_pad_i    ( i_gpio_i2c_sda    ),
    .sda_pad_o    ( o_gpio_i2c_sda    ),
    .sda_padoen_o ( w_sda_padoen      )
  );

  assign o_gpio_i2c_scl_oe = ~w_scl_padoen;
  assign o_gpio_i2c_sda_oe = ~w_sda_padoen;

endmodule
