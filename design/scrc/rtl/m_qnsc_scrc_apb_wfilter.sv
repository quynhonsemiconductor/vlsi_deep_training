`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc_apb_wfilter -- write filter, one per master (QNSC_SCRC_MAS V3.4,
// 7.4, Table 7-2)
//
// APB-CSR-Generator sees one slave and cannot tell the masters apart, so each
// master's path has a filter in front of the APB BUS:
//   - a write to an offset this master may only read is dropped (PSEL never
//     reaches the bus) and answered here with PREADY = 1, PSLVERR = 1;
//   - any access to 0x1C (inside the bus window, no register) gives PSLVERR;
//   - reads pass; offsets 0x0020..0x3FFF are left to the APB BUS (PSLVERR).
// A dropped write changes no register (SCRC_CSR_001). MCPU has no PSLVERR
// input, so for MCPU a dropped write is silent.
//
// s_0 is the master's side, m_0 the APB BUS side. Combinational: PADDR and
// PWRITE are stable for the whole APB transfer. PADDR, PWRITE, PWDATA, PSTRB,
// PPROT go straight from the master to the bus.
//
//   offset  0x00 0x04 0x08 0x0C 0x10 0x14 0x18 0x1C
//   bit k     0    1    2    3    4    5    6    7
//   Ibex     -    -    -    x    x    x    x         P_WR_DENY = 8'b0111_1000
//   MCPU     x    x    -    -    -    -    x         P_WR_DENY = 8'b0100_0011
// =============================================================================
module m_qnsc_scrc_apb_wfilter #(
  parameter logic [7:0] P_WR_DENY = 8'h00   // bit k = 1: drop writes to offset 4*k
) (
  // master side
  input  logic        i_bus_apb_s_0_psel,
  input  logic        i_bus_apb_s_0_penable,
  input  logic        i_bus_apb_s_0_pwrite,
  input  logic [13:0] i_bus_apb_s_0_paddr,     // contract: meta.apb_paddr_width
  output logic        o_bus_apb_s_0_pready,
  output logic        o_bus_apb_s_0_pslverr,
  output logic [31:0] o_bus_apb_s_0_prdata,
  // APB BUS side
  output logic        o_bus_apb_m_0_psel,
  output logic        o_bus_apb_m_0_penable,
  input  logic        i_bus_apb_m_0_pready,
  input  logic        i_bus_apb_m_0_pslverr,
  input  logic [31:0] i_bus_apb_m_0_prdata
);

  logic w_in_win, w_deny;

  assign w_in_win = (i_bus_apb_s_0_paddr[13:5] == 9'd0);                     // 0x00..0x1F
  assign w_deny   = w_in_win & ((i_bus_apb_s_0_paddr[4:2] == 3'd7)           // 0x1C
                              | (i_bus_apb_s_0_pwrite & P_WR_DENY[i_bus_apb_s_0_paddr[4:2]]));

  assign o_bus_apb_m_0_psel    = i_bus_apb_s_0_psel    & ~w_deny;
  assign o_bus_apb_m_0_penable = i_bus_apb_s_0_penable & ~w_deny;
  assign o_bus_apb_s_0_pready  = w_deny ? 1'b1  : i_bus_apb_m_0_pready;
  assign o_bus_apb_s_0_pslverr = w_deny ? 1'b1  : i_bus_apb_m_0_pslverr;
  assign o_bus_apb_s_0_prdata  = w_deny ? 32'd0 : i_bus_apb_m_0_prdata;

endmodule
