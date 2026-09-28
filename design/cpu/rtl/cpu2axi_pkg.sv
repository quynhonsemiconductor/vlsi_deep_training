`default_nettype none
//==============================================================================
// Module      : cpu2axi_pkg
// Description : AXI4 struct typedefs for the CPU2AXI bridge and its S_BUS-facing
//               master port. "leaf" = pre-mux, per-memory-port ID width (4 bit).
//               "axi_s_1" = post-mux, S_BUS AXI_S1 slave-port ID width (5 bit).
// Spec ref    : doc/specs/QNSC_CPU_MAS.md
//==============================================================================
`include "axi/typedef.svh"

package cpu2axi_pkg;

  localparam int unsigned P_AXI_ADDR_W = 32;
  localparam int unsigned P_AXI_DATA_W = 32;
  localparam int unsigned P_AXI_STRB_W = P_AXI_DATA_W / 8;
  localparam int unsigned P_AXI_USER_W = 1;

  // ---- Pre-mux (leaf) types: one per axi_from_mem instance ----
  localparam int unsigned P_LEAF_ID_W = 4;

  typedef logic [P_AXI_ADDR_W-1:0] addr_t;
  typedef logic [P_AXI_DATA_W-1:0] data_t;
  typedef logic [P_AXI_STRB_W-1:0] strb_t;
  typedef logic [P_AXI_USER_W-1:0] user_t;
  typedef logic [P_LEAF_ID_W-1:0]  leaf_id_t;

  `AXI_TYPEDEF_ALL(leaf, addr_t, leaf_id_t, data_t, strb_t, user_t)

  // ---- Post-mux type: the merged AXI4 master port toward S_BUS AXI_S1 ----
  // REQ-021 / E3: width must match S_BUS's AXI_S1 slave-port ID width once
  // S_BUS is implemented -- not checkable from this IP alone.
  localparam int unsigned P_MST_ID_W = P_LEAF_ID_W + 1; // +$clog2(NoSlvPorts=2)

  typedef logic [P_MST_ID_W-1:0] axi_s_1_id_t;

  `AXI_TYPEDEF_ALL(axi_s_1, addr_t, axi_s_1_id_t, data_t, strb_t, user_t)

endpackage
`default_nettype wire
