// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Nils Wistoff <nwistoff@iis.ee.ethz.ch>
//
// QNSC: derived from vendor/pulp-platform/apb_uart/src/apb_uart_wrap.sv,
// renamed and normalized at the wrapper boundary per QNSC RTL Design Naming
// Rule V1.0. The UART core is obi_uart from vendor/pulp-platform/obi_peripherals
// with vendor/patches/pulp-platform_obi_peripherals/ applied, which adds the
// DMA request lines. apb_uart_wrap itself is not used because it has no DMA
// ports.

`include "apb/typedef.svh"
`include "obi/typedef.svh"

import qnsc_pkg::*;

// QNSC wrapper of the PULP OBI UART for the QSOC peripheral bus.
// design/top instantiates it twice: u_uart_0 on APB_M9, u_uart_1 on APB_M10.
module m_qnsc_wrap_apb_uart #(
  // P_BUS address width. One width for every peripheral slave is still tbd: in
  // util/qsoc_contract.yml (bus owner); until then it covers the 16 KiB window.
  parameter int unsigned P_ADDR_WIDTH      = $clog2(C_UART_0_SIZE),  // naming-check: ignore -- $clog2 is a system function
  parameter int unsigned P_SLOT_ADDR_WIDTH = $clog2(C_UART_0_SIZE),  // naming-check: ignore -- $clog2 is a system function; 16 KiB slot
  parameter bit          P_STRICT_DECODE   = 1'b1 // PSLVERR for slot offsets >= 0x20
) (
  // Clock and reset, peri cluster (gateable by SCRC CLK_EN; the bit positions
  // are tbd: in util/qsoc_contract.yml, SCRC owner)
  input  logic                    i_clk_peri,
  input  logic                    i_rst_n_peri,

  // APB4 slave (P_BUS)
  input  logic [P_ADDR_WIDTH-1:0] i_bus_apb_paddr,
  input  logic [2:0]              i_bus_apb_pprot,
  input  logic                    i_bus_apb_psel,
  input  logic                    i_bus_apb_penable,
  input  logic                    i_bus_apb_pwrite,
  input  logic [31:0]             i_bus_apb_pwdata,
  input  logic [3:0]              i_bus_apb_pstrb,
  output logic [31:0]             o_bus_apb_prdata,
  output logic                    o_bus_apb_pready,
  output logic                    o_bus_apb_pslverr,

  // Interrupt to INTMAP (fast line C_INT_LINE_UART_0 / C_INT_LINE_UART_1, level)
  output logic                    o_int_uart,

  // DMA request lines for the QSOC peripheral-triggered DMA channels
  output logic                    o_dma_tx_req,
  output logic                    o_dma_rx_req,

  // Serial pins towards IOMUX (RX must be driven idle-high when unselected)
  input  logic                    i_gpio_uart_rx,
  output logic                    o_gpio_uart_tx,
  output logic                    o_gpio_uart_tx_oe
);

  `APB_TYPEDEF_ALL(apb, logic [P_ADDR_WIDTH-1:0], logic [31:0], logic [3:0])

  localparam obi_pkg::obi_cfg_t C_OBI_CFG = obi_pkg::obi_default_cfg(
      P_ADDR_WIDTH,
      32,
      1,
      obi_pkg::ObiMinimalOptionalConfig  // naming-check: ignore -- member of vendored obi_pkg
  );

  `OBI_TYPEDEF_DEFAULT_ALL(obi, C_OBI_CFG)

  logic      w_addr_hit;
  logic      w_addr_err;
  apb_req_t  w_apb_req;
  apb_resp_t w_apb_rsp;
  obi_req_t  w_obi_req;
  obi_rsp_t  w_obi_rsp;

  // Offset decode: only 0x00..0x1C of the slot hold UART registers
  assign w_addr_hit = P_STRICT_DECODE ? (i_bus_apb_paddr[P_SLOT_ADDR_WIDTH-1:5] == '0) : 1'b1;
  assign w_addr_err = i_bus_apb_psel & ~w_addr_hit;

  // Flat QNSC APB ports -> third-party APB struct
  assign w_apb_req = '{
    paddr:   i_bus_apb_paddr,
    pprot:   i_bus_apb_pprot,
    psel:    i_bus_apb_psel & w_addr_hit,
    penable: i_bus_apb_penable,
    pwrite:  i_bus_apb_pwrite,
    pwdata:  i_bus_apb_pwdata,
    pstrb:   i_bus_apb_pstrb
  };

  // Out-of-range offsets complete immediately with an error, core untouched
  assign o_bus_apb_prdata  = w_addr_err ? '0 : w_apb_rsp.prdata;
  assign o_bus_apb_pready  = w_addr_err | w_apb_rsp.pready;
  assign o_bus_apb_pslverr = w_addr_err | w_apb_rsp.pslverr;

  apb_to_obi #(
    .ObiCfg    ( C_OBI_CFG  ),
    .apb_req_t ( apb_req_t  ),
    .apb_rsp_t ( apb_resp_t ),
    .obi_req_t ( obi_req_t  ),
    .obi_rsp_t ( obi_rsp_t  )
  ) u_apb_to_obi (
    .clk_i     ( i_clk_peri   ),
    .rst_ni    ( i_rst_n_peri ),
    .apb_req_i ( w_apb_req    ),
    .apb_rsp_o ( w_apb_rsp    ),
    .obi_req_o ( w_obi_req    ),
    .obi_rsp_i ( w_obi_rsp    )
  );

  obi_uart #(
    .ObiCfg    ( C_OBI_CFG ),
    .obi_req_t ( obi_req_t ),
    .obi_rsp_t ( obi_rsp_t )
  ) u_uart (
    .clk_i        ( i_clk_peri     ),
    .rst_ni       ( i_rst_n_peri   ),
    .obi_req_i    ( w_obi_req      ),
    .obi_rsp_o    ( w_obi_rsp      ),
    .irq_o        ( o_int_uart     ),
    .irq_no       (                ),
    .dma_tx_req_o ( o_dma_tx_req   ),
    .dma_rx_req_o ( o_dma_rx_req   ),
    .rxd_i        ( i_gpio_uart_rx ),
    .txd_o        ( o_gpio_uart_tx ),
    // Modem inputs tied inactive: matches the '1 reset value of the modem
    // synchronizers, so no delta (MSR/MSTAT) event is raised after reset
    .cts_ni       ( 1'b1           ),
    .dsr_ni       ( 1'b1           ),
    .ri_ni        ( 1'b1           ),
    .cd_ni        ( 1'b1           ),
    .rts_no       (                ),
    .dtr_no       (                ),
    .out1_no      (                ),
    .out2_no      (                )
  );

  assign o_gpio_uart_tx_oe = 1'b1;

endmodule
