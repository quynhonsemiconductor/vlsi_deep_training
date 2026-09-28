`default_nettype none
//==============================================================================
// Module      : m_qnsc_cpu2axi
// Description : Merges Ibex's two memory-style ports (instruction, data) into
//               one AXI4 master port, via 2x axi_from_mem (pulp-platform/axi)
//               + 1x axi_mux (same IP). Self-designed merge point --
//               axi_from_mem and axi_mux themselves are external, unmodified
//               IP; see vendor/manifest.yml for the pinned commit.
// Parent      : m_qnsc_wrap_cpu (flattens the AXI4 port to i_bus_axi_*/
//               o_bus_axi_* at the wrapper boundary; this module keeps the
//               packed-struct port the vendor IP itself speaks)
// Spec ref    : doc/specs/QNSC_CPU_MAS.md
//==============================================================================
module m_qnsc_cpu2axi
  import cpu2axi_pkg::*;
#(
  parameter int unsigned P_MAX_REQUESTS = 2, // REQ-027: matches Ibex's outstanding depth
  parameter int unsigned P_MAX_W_TRANS  = 2,
  parameter bit          P_FALL_THROUGH = 1'b0,
  parameter bit          P_SPILL_AW     = 1'b1,
  parameter bit          P_SPILL_W      = 1'b0,
  parameter bit          P_SPILL_B      = 1'b0,
  parameter bit          P_SPILL_AR     = 1'b1,
  parameter bit          P_SPILL_R      = 1'b0
) (
  // ---- Clock & Reset ----
  input  logic i_clk_core,
  input  logic i_resetn_core,

  // ---- Instruction memory-style slave port (from Ibex instr_*) ---- // REQ-013,REQ-015
  input  logic        i_instr_req,
  output logic        o_instr_gnt,
  output logic        o_instr_rvalid,
  input  logic [31:0] i_instr_addr,
  output logic [31:0] o_instr_rdata,
  output logic        o_instr_err,       // REQ-017,REQ-028

  // ---- Data memory-style slave port (from Ibex data_*) ---- // REQ-013
  input  logic        i_data_req,
  output logic        o_data_gnt,
  output logic        o_data_rvalid,
  input  logic        i_data_we,
  input  logic [3:0]  i_data_be,
  input  logic [31:0] i_data_addr,
  input  logic [31:0] i_data_wdata,
  output logic [31:0] o_data_rdata,
  output logic        o_data_err,        // REQ-017,REQ-028

  // ---- AXI4 master port (to S_BUS AXI_S1) ---- // REQ-014,REQ-018,REQ-020
  output axi_s_1_req_t  o_axi_req,
  input  axi_s_1_resp_t i_axi_resp
);

  // Port order into axi_mux is fixed: 0 = instruction, 1 = data. // REQ-020 (E2)
  localparam int unsigned P_PORT_INSTR = 0;
  localparam int unsigned P_PORT_DATA  = 1;
  localparam int unsigned P_NO_SLV_PORTS = 2;

  leaf_req_t  [P_NO_SLV_PORTS-1:0] w_leaf_req;
  leaf_resp_t [P_NO_SLV_PORTS-1:0] w_leaf_resp;

  // ---- Instruction port: memory-style -> AXI4-Lite -> AXI4 (leaf ID width) ----
  // No write path exists on this port. // REQ-015
  axi_from_mem #(
    .MemAddrWidth (32),
    .AxiAddrWidth (cpu2axi_pkg::P_AXI_ADDR_W),
    .DataWidth    (cpu2axi_pkg::P_AXI_DATA_W),
    .MaxRequests  (P_MAX_REQUESTS),
    .AxiProt      (3'b100),           // AxPROT[2]: instruction access
    .axi_req_t    (leaf_req_t),
    .axi_rsp_t    (leaf_resp_t)
  ) u_instr_from_mem (
    .clk_i           (i_clk_core),
    .rst_ni          (i_resetn_core),
    .mem_req_i       (i_instr_req),
    .mem_addr_i      (i_instr_addr),
    .mem_we_i        (1'b0),          // REQ-015: instruction port never writes
    .mem_wdata_i     ('0),
    .mem_be_i        ({(cpu2axi_pkg::P_AXI_STRB_W){1'b1}}),
    .mem_gnt_o       (o_instr_gnt),
    .mem_rsp_valid_o (o_instr_rvalid),
    .mem_rsp_rdata_o (o_instr_rdata),
    .mem_rsp_error_o (o_instr_err),    // REQ-017
    .slv_aw_cache_i  (axi_pkg::CACHE_MODIFIABLE),
    .slv_ar_cache_i  (axi_pkg::CACHE_MODIFIABLE),
    .axi_req_o       (w_leaf_req[P_PORT_INSTR]),
    .axi_rsp_i       (w_leaf_resp[P_PORT_INSTR])
  );

  // ---- Data port: memory-style -> AXI4-Lite -> AXI4 (leaf ID width) ----
  axi_from_mem #(
    .MemAddrWidth (32),
    .AxiAddrWidth (cpu2axi_pkg::P_AXI_ADDR_W),
    .DataWidth    (cpu2axi_pkg::P_AXI_DATA_W),
    .MaxRequests  (P_MAX_REQUESTS),
    .AxiProt      (3'b000),
    .axi_req_t    (leaf_req_t),
    .axi_rsp_t    (leaf_resp_t)
  ) u_data_from_mem (
    .clk_i           (i_clk_core),
    .rst_ni          (i_resetn_core),
    .mem_req_i       (i_data_req),
    .mem_addr_i      (i_data_addr),
    .mem_we_i        (i_data_we),
    .mem_wdata_i     (i_data_wdata),
    .mem_be_i        (i_data_be),      // REQ-013: byte enables passed straight through
    .mem_gnt_o       (o_data_gnt),
    .mem_rsp_valid_o (o_data_rvalid),
    .mem_rsp_rdata_o (o_data_rdata),
    .mem_rsp_error_o (o_data_err),     // REQ-017
    .slv_aw_cache_i  (axi_pkg::CACHE_MODIFIABLE),
    .slv_ar_cache_i  (axi_pkg::CACHE_MODIFIABLE),
    .axi_req_o       (w_leaf_req[P_PORT_DATA]),
    .axi_rsp_i       (w_leaf_resp[P_PORT_DATA])
  );

  // ---- Merge: round-robin arbitration, port-index in top ID bit ---- // REQ-012,REQ-014,REQ-018
  axi_mux #(
    .SlvAxiIDWidth (cpu2axi_pkg::P_LEAF_ID_W),
    .slv_aw_chan_t (leaf_aw_chan_t),
    .mst_aw_chan_t (axi_s_1_aw_chan_t),
    .w_chan_t      (leaf_w_chan_t),
    .slv_b_chan_t  (leaf_b_chan_t),
    .mst_b_chan_t  (axi_s_1_b_chan_t),
    .slv_ar_chan_t (leaf_ar_chan_t),
    .mst_ar_chan_t (axi_s_1_ar_chan_t),
    .slv_r_chan_t  (leaf_r_chan_t),
    .mst_r_chan_t  (axi_s_1_r_chan_t),
    .slv_req_t     (leaf_req_t),
    .slv_resp_t    (leaf_resp_t),
    .mst_req_t     (axi_s_1_req_t),
    .mst_resp_t    (axi_s_1_resp_t),
    .NoSlvPorts    (P_NO_SLV_PORTS),  // REQ-020 (E2): fixed at 2
    .MaxWTrans     (P_MAX_W_TRANS),
    .FallThrough   (P_FALL_THROUGH),
    .SpillAw       (P_SPILL_AW),
    .SpillW        (P_SPILL_W),
    .SpillB        (P_SPILL_B),
    .SpillAr       (P_SPILL_AR),
    .SpillR        (P_SPILL_R)
  ) u_axi_mux (
    .clk_i       (i_clk_core),
    .rst_ni      (i_resetn_core),
    // No test_i port at this repo's pinned axi commit (70b8e54f); it was
    // added in a later axi release. See vendor/manifest.yml.
    .slv_reqs_i  (w_leaf_req),
    .slv_resps_o (w_leaf_resp),
    .mst_req_o   (o_axi_req),
    .mst_resp_i  (i_axi_resp)
  );

endmodule
`default_nettype wire
