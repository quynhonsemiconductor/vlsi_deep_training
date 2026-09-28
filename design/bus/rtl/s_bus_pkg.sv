`default_nettype none
`timescale 1ns/1ps
//==============================================================================
// Module      : s_bus_pkg
// Description : AXI4 struct typedefs, axi_xbar Cfg and address map for S_BUS.
//               bus is an integration block (design/README.md, "Shared numbers:
//               who may use qnsc_pkg"), so this package imports qnsc_pkg
//               directly rather than taking values on i_cfg_* ports.
// Spec ref    : doc/specs/QNSC_BUS_MAS.md
//==============================================================================
`include "axi/typedef.svh"

package s_bus_pkg;

  import qnsc_pkg::C_ADDR_WIDTH;
  import qnsc_pkg::C_DATA_WIDTH;

  localparam int unsigned P_AXI_ADDR_W = C_ADDR_WIDTH;
  localparam int unsigned P_AXI_DATA_W = C_DATA_WIDTH;
  localparam int unsigned P_AXI_STRB_W = P_AXI_DATA_W / 8;
  localparam int unsigned P_AXI_USER_W = 1;

  // Three masters issue transactions on S_BUS (QNSC_RAM_DECISIONS: "CPU2AXI on
  // AXI_S1, SYSDBG on AXI_S0, and DMA on AXI_S2"); four destinations answer
  // them (rom AXI_M0, isram AXI_M1, dsram AXI_M2, the AXI2APB bridge AXI_M3).
  // No PLIC: QNSC_Interrupt_Map_DECISIONS V11.2 removed it from the memory
  // map, so there is no fifth master port here.
  localparam int unsigned P_NO_SLV_PORTS = 3;
  localparam int unsigned P_NO_MST_PORTS = 4;

  // AXI_S0 (SYSDBG) and AXI_S1 (CPU) are both confirmed 5-bit (SYSDBG's own
  // AxiIdWidth, and cpu2axi_pkg::P_MST_ID_W). AXI_S2 (DMA) is assumed 5-bit
  // too for uniformity -- design/dma has no MAS yet to confirm this, and
  // HAS para 852's "identifier width 7" more likely describes the crossbar's
  // own auto-widened master-port ID below than DMA's own port width. Open
  // item for the DMA owner: see QNSC_BUS_DECISIONS.md.
  localparam int unsigned P_SLV_ID_W = 5;
  // axi_mux inside axi_xbar widens the ID by ceil(log2(NoSlvPorts)) per
  // master port -- not set by hand, this is what Cfg documents.
  localparam int unsigned P_MST_ID_W = P_SLV_ID_W + $clog2(P_NO_SLV_PORTS);

  typedef logic [P_AXI_ADDR_W-1:0] addr_t;
  typedef logic [P_AXI_DATA_W-1:0] data_t;
  typedef logic [P_AXI_STRB_W-1:0] strb_t;
  typedef logic [P_AXI_USER_W-1:0] user_t;
  typedef logic [P_SLV_ID_W-1:0]   slv_id_t;
  typedef logic [P_MST_ID_W-1:0]   mst_id_t;

  // The W channel carries no ID field, so it is generated once and shared
  // across both ID widths -- calling `AXI_TYPEDEF_ALL` separately per width
  // instead would produce two structurally-identical but distinctly-named
  // w_chan_t types that cannot both satisfy axi_xbar's single shared
  // w_chan_t parameter (S_BUS reference notes, section 2.6).
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)

  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_chan_t, addr_t, slv_id_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(slv_b_chan_t, slv_id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_chan_t, addr_t, slv_id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(slv_r_chan_t, data_t, slv_id_t, user_t)
  `AXI_TYPEDEF_REQ_T(slv_req_t, slv_aw_chan_t, w_chan_t, slv_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(slv_resp_t, slv_b_chan_t, slv_r_chan_t)

  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_chan_t, addr_t, mst_id_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(mst_b_chan_t, mst_id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_chan_t, addr_t, mst_id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(mst_r_chan_t, data_t, mst_id_t, user_t)
  `AXI_TYPEDEF_REQ_T(mst_req_t, mst_aw_chan_t, w_chan_t, mst_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(mst_resp_t, mst_b_chan_t, mst_r_chan_t)

  typedef axi_pkg::xbar_rule_32_t rule_t;
  localparam int unsigned P_NO_ADDR_RULES = P_NO_MST_PORTS;  // one rule per master port

  // Table 5-1 equivalent: "every slave port reaches every master port"
  // (Connectivity left at its default '1, full crossbar, at the instance).
  //
  // Built by an automatic function, not a struct literal: Verilator's own
  // width check treats a struct literal as a concatenation and flags every
  // field that is not a same-width sized literal (WIDTHCONCAT), even a
  // same-width `int unsigned` localparam reference. Plain field-by-field
  // assignment in a function body has no such warning.
  function automatic axi_pkg::xbar_cfg_t cfg_f();
    axi_pkg::xbar_cfg_t c;
    c.NoSlvPorts         = P_NO_SLV_PORTS;
    c.NoMstPorts         = P_NO_MST_PORTS;
    c.MaxMstTrans        = 2;   // "Outstanding transactions: 2 per port"
    c.MaxSlvTrans        = 2;
    c.FallThrough        = 1'b0;                 // required 0 when using CUT_ALL_AX
    c.LatencyMode        = axi_pkg::CUT_ALL_AX;   // register stage: cut every Ax channel
    c.PipelineStages     = 0;
    c.AxiIdWidthSlvPorts = P_SLV_ID_W;
    // Open items, no chip-level requirement forces a different value yet;
    // see QNSC_BUS_DECISIONS.md for the reasoning kept alongside each:
    c.AxiIdUsedSlvPorts  = P_SLV_ID_W;  // full width kept for safety
    c.UniqueIds          = 1'b0;  // safe default until CPU/DMA/debug ID uniqueness is confirmed
    c.AxiAddrWidth       = P_AXI_ADDR_W;
    c.AxiDataWidth       = P_AXI_DATA_W;
    c.NoAddrRules        = P_NO_ADDR_RULES;
    return c;
  endfunction
  localparam axi_pkg::xbar_cfg_t P_CFG = cfg_f();

  // Address map. axi_xbar treats end_addr as EXCLUSIVE; qnsc_pkg's *_BASE/
  // *_SIZE pairs already give an exclusive bound directly as base + size, so
  // no +1 correction is needed (unlike the reference guide's own note, which
  // was about a different, inclusive-end source table).
  //
  // AXI_M1 covers isram_dbg AND isram as one contiguous rule: the two are
  // adjacent (isram_dbg ends exactly where isram begins) and both reach the
  // same physical RAM instance through the same wrapper port.
  function automatic rule_t [P_NO_ADDR_RULES-1:0] addr_map_f();
    rule_t [P_NO_ADDR_RULES-1:0] m;
    m[0].idx = 0;  m[0].start_addr = qnsc_pkg::C_ROM_BASE;
                   m[0].end_addr   = qnsc_pkg::C_ROM_BASE + qnsc_pkg::C_ROM_SIZE;
    m[1].idx = 1;  m[1].start_addr = qnsc_pkg::C_ISRAM_DBG_BASE;
                   m[1].end_addr   = qnsc_pkg::C_ISRAM_BASE + qnsc_pkg::C_ISRAM_SIZE;
    m[2].idx = 2;  m[2].start_addr = qnsc_pkg::C_DSRAM_BASE;
                   m[2].end_addr   = qnsc_pkg::C_DSRAM_BASE + qnsc_pkg::C_DSRAM_SIZE;
    m[3].idx = 3;  m[3].start_addr = qnsc_pkg::C_AXI2APB_BASE;
                   m[3].end_addr   = qnsc_pkg::C_AXI2APB_BASE + qnsc_pkg::C_AXI2APB_SIZE;
    return m;
  endfunction
  localparam rule_t [P_NO_ADDR_RULES-1:0] P_ADDR_MAP = addr_map_f();

  // ---- AXI4-Lite (between axi_to_axi_lite and axi_lite_to_apb) -------------
  // AXI4-Lite has no ID and no USER field, so it needs its own dedicated
  // macro family (`AXI_LITE_TYPEDEF_*), not the full AXI4 one above.
  `AXI_LITE_TYPEDEF_ALL_CT(lite, lite_req_t, lite_resp_t, addr_t, data_t, strb_t)

  // ---- APB4 (between axi_lite_to_apb and the P_BUS router) -----------------
  // Local to this bridge only, never a block boundary: axi_lite_to_apb takes
  // NoApbSlaves=1 here (its single output is P_BUS's own single master-input
  // port, APB_S0; P_BUS's generated router does the real per-peripheral
  // fan-out, a separate step). Not exposed on m_qnsc_wrap_bus's own ports,
  // which flatten this to individual i_apb_*/o_apb_* signals instead, so
  // this struct never needs naming-rule review.
  localparam int unsigned P_NO_APB_SLAVES = 1;
  localparam int unsigned P_NO_APB_RULES  = 1;

  // Field names are the APB4 protocol's own (ARM IHI 0024), not internal
  // signals, so they keep the protocol's p<name> spelling rather than an
  // r_/w_/mem_ prefix -- same reason the AXI channel field names above
  // (id/addr/len/...) are never renamed either; those simply aren't visible
  // to naming_check.py's text scan since they come from a macro expansion.
  typedef struct packed {
    addr_t          paddr;
    axi_pkg::prot_t pprot;
    logic           psel;     // naming-check: ignore -- APB4 protocol field, not an internal signal
    logic           penable;  // naming-check: ignore -- APB4 protocol field, not an internal signal
    logic           pwrite;   // naming-check: ignore -- APB4 protocol field, not an internal signal
    data_t          pwdata;
    strb_t          pstrb;
  } apb_req_t;

  typedef struct packed {
    logic           pready;   // naming-check: ignore -- APB4 protocol field, not an internal signal
    data_t          prdata;
    logic           pslverr;  // naming-check: ignore -- APB4 protocol field, not an internal signal
  } apb_resp_t;

  // One rule: the whole AXI2APB window forwards to APB_S0. axi_lite_to_apb's
  // own rule_t reuses the same shape as the crossbar's (idx/start_addr/
  // end_addr), also exclusive-end.
  function automatic rule_t [P_NO_APB_RULES-1:0] apb_addr_map_f();
    rule_t [P_NO_APB_RULES-1:0] m;
    m[0].idx = 0;
    m[0].start_addr = qnsc_pkg::C_AXI2APB_BASE;
    m[0].end_addr   = qnsc_pkg::C_AXI2APB_BASE + qnsc_pkg::C_AXI2APB_SIZE;
    return m;
  endfunction
  localparam rule_t [P_NO_APB_RULES-1:0] P_APB_ADDR_MAP = apb_addr_map_f();

endpackage : s_bus_pkg
`default_nettype wire
