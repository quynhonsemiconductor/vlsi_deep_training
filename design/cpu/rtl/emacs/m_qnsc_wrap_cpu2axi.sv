`timescale 1ns/1ps

module m_qnsc_wrap_cpu2axi
  import cpu2axi_pkg::*;
#(
)
(
//---------------------------------------------------------------
// Clock/Reset
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic		i_clk_cpu,		// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
input logic		i_rst_n_cpu,		// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
// End of automatics

//---------------------------------------------------------------
// Instruction memory interface (from m_qnsc_wrap_ibex o_mem_instr_*)
//---------------------------------------------------------------
/*AUTOINPUT("^i_mem_instr")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [31:0]	i_mem_instr_addr,	// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
input logic		i_mem_instr_req,	// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
// End of automatics
/*AUTOOUTPUT("^o_mem_instr")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_mem_instr_err,	// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
output logic		o_mem_instr_gnt,	// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
output logic [31:0]	o_mem_instr_rdata,	// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
output logic		o_mem_instr_rvalid,	// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
// End of automatics

//---------------------------------------------------------------
// Data memory interface (from m_qnsc_wrap_ibex o_mem_data_*)
//---------------------------------------------------------------
/*AUTOINPUT("^i_mem_data")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [31:0]	i_mem_data_addr,	// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
input logic [3:0]	i_mem_data_be,		// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
input logic		i_mem_data_req,		// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
input logic [31:0]	i_mem_data_wdata,	// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
input logic		i_mem_data_we,		// To u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
// End of automatics
/*AUTOOUTPUT("^o_mem_data")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic		o_mem_data_err,		// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
output logic		o_mem_data_gnt,		// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
output logic [31:0]	o_mem_data_rdata,	// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
output logic		o_mem_data_rvalid,	// From u_m_qnsc_cpu2axi of m_qnsc_cpu2axi.v
// End of automatics

//---------------------------------------------------------------
// AXI4 master bus -- flattened per QNSC naming rule (no packed
// structs on the wrapper boundary). AW/W/AR are driven by this
// bridge (o_bus_axi_*); B/R are driven by the slave subsystem
// (i_bus_axi_*). *_ready runs against the channel's own flow
// direction: i_bus_axi_aw_ready / o_bus_axi_b_ready etc.
//---------------------------------------------------------------
input  logic                    i_bus_axi_aw_ready,
output logic [P_MST_ID_W-1:0]  o_bus_axi_aw_id,
output logic [31:0]             o_bus_axi_aw_addr,
output logic [7:0]              o_bus_axi_aw_len,
output logic [2:0]              o_bus_axi_aw_size,
output logic [1:0]              o_bus_axi_aw_burst,
output logic                    o_bus_axi_aw_lock,
output logic [3:0]              o_bus_axi_aw_cache,
output logic [2:0]              o_bus_axi_aw_prot,
output logic [3:0]              o_bus_axi_aw_qos,
output logic [3:0]              o_bus_axi_aw_region,
output logic [5:0]              o_bus_axi_aw_atop,
output logic [P_AXI_USER_W-1:0] o_bus_axi_aw_user,
output logic                    o_bus_axi_aw_valid,

input  logic                    i_bus_axi_w_ready,
output logic [31:0]             o_bus_axi_w_data,
output logic [3:0]              o_bus_axi_w_strb,
output logic                    o_bus_axi_w_last,
output logic [P_AXI_USER_W-1:0] o_bus_axi_w_user,
output logic                    o_bus_axi_w_valid,

output logic                    o_bus_axi_b_ready,
input  logic [P_MST_ID_W-1:0]  i_bus_axi_b_id,
input  logic [1:0]              i_bus_axi_b_resp,
input  logic [P_AXI_USER_W-1:0] i_bus_axi_b_user,
input  logic                    i_bus_axi_b_valid,

input  logic                    i_bus_axi_ar_ready,
output logic [P_MST_ID_W-1:0]  o_bus_axi_ar_id,
output logic [31:0]             o_bus_axi_ar_addr,
output logic [7:0]              o_bus_axi_ar_len,
output logic [2:0]              o_bus_axi_ar_size,
output logic [1:0]              o_bus_axi_ar_burst,
output logic                    o_bus_axi_ar_lock,
output logic [3:0]              o_bus_axi_ar_cache,
output logic [2:0]              o_bus_axi_ar_prot,
output logic [3:0]              o_bus_axi_ar_qos,
output logic [3:0]              o_bus_axi_ar_region,
output logic [P_AXI_USER_W-1:0] o_bus_axi_ar_user,
output logic                    o_bus_axi_ar_valid,

output logic                    o_bus_axi_r_ready,
input  logic [P_MST_ID_W-1:0]  i_bus_axi_r_id,
input  logic [31:0]             i_bus_axi_r_data,
input  logic [1:0]              i_bus_axi_r_resp,
input  logic                    i_bus_axi_r_last,
input  logic [P_AXI_USER_W-1:0] i_bus_axi_r_user,
input  logic                    i_bus_axi_r_valid
);


/*AUTOWIRE*/

/* m_qnsc_cpu2axi AUTO_TEMPLATE(
    .i_clk_core    (i_clk_cpu),
    .i_resetn_core (i_rst_n_cpu),
    .i_instr_req   (i_mem_instr_req),
    .o_instr_gnt   (o_mem_instr_gnt),
    .o_instr_rvalid (o_mem_instr_rvalid),
    .i_instr_addr  (i_mem_instr_addr[]),
    .o_instr_rdata (o_mem_instr_rdata[]),
    .o_instr_err   (o_mem_instr_err),
    .i_data_req    (i_mem_data_req),
    .o_data_gnt    (o_mem_data_gnt),
    .o_data_rvalid (o_mem_data_rvalid),
    .i_data_we     (i_mem_data_we),
    .i_data_be     (i_mem_data_be[]),
    .i_data_addr   (i_mem_data_addr[]),
    .i_data_wdata  (i_mem_data_wdata[]),
    .o_data_rdata  (o_mem_data_rdata[]),
    .o_data_err    (o_mem_data_err),
    .o_axi_req     (w_bridge_axi_req),
    .i_axi_resp    (w_bridge_axi_resp),
);
*/
cpu2axi_pkg::axi_s_1_req_t  w_bridge_axi_req;
cpu2axi_pkg::axi_s_1_resp_t w_bridge_axi_resp;

m_qnsc_cpu2axi u_m_qnsc_cpu2axi(/*AUTOINST*/
				// Interfaces
				.o_axi_req	(w_bridge_axi_req), // Templated
				.i_axi_resp	(w_bridge_axi_resp), // Templated
				// Outputs
				.o_instr_gnt	(o_mem_instr_gnt), // Templated
				.o_instr_rvalid	(o_mem_instr_rvalid), // Templated
				.o_instr_rdata	(o_mem_instr_rdata[31:0]), // Templated
				.o_instr_err	(o_mem_instr_err), // Templated
				.o_data_gnt	(o_mem_data_gnt), // Templated
				.o_data_rvalid	(o_mem_data_rvalid), // Templated
				.o_data_rdata	(o_mem_data_rdata[31:0]), // Templated
				.o_data_err	(o_mem_data_err), // Templated
				// Inputs
				.i_clk_core	(i_clk_cpu),	 // Templated
				.i_resetn_core	(i_rst_n_cpu),	 // Templated
				.i_instr_req	(i_mem_instr_req), // Templated
				.i_instr_addr	(i_mem_instr_addr[31:0]), // Templated
				.i_data_req	(i_mem_data_req), // Templated
				.i_data_we	(i_mem_data_we), // Templated
				.i_data_be	(i_mem_data_be[3:0]), // Templated
				.i_data_addr	(i_mem_data_addr[31:0]), // Templated
				.i_data_wdata	(i_mem_data_wdata[31:0])); // Templated

//---------------------------------------------------------------
// Boundary normalization: pack/unpack the QNSC flattened AXI4
// master port against the pulp-platform packed-struct port used
// by the (unmodified, third-party-adjacent) cpu2axi_bridge core.
// AUTOINST cannot decompose SV packed structs, so this glue is
// hand-written, not tool-generated.
//---------------------------------------------------------------
assign o_bus_axi_aw_id     = w_bridge_axi_req.aw.id;
assign o_bus_axi_aw_addr   = w_bridge_axi_req.aw.addr;
assign o_bus_axi_aw_len    = w_bridge_axi_req.aw.len;
assign o_bus_axi_aw_size   = w_bridge_axi_req.aw.size;
assign o_bus_axi_aw_burst  = w_bridge_axi_req.aw.burst;
assign o_bus_axi_aw_lock   = w_bridge_axi_req.aw.lock;
assign o_bus_axi_aw_cache  = w_bridge_axi_req.aw.cache;
assign o_bus_axi_aw_prot   = w_bridge_axi_req.aw.prot;
assign o_bus_axi_aw_qos    = w_bridge_axi_req.aw.qos;
assign o_bus_axi_aw_region = w_bridge_axi_req.aw.region;
assign o_bus_axi_aw_atop   = w_bridge_axi_req.aw.atop;
assign o_bus_axi_aw_user   = w_bridge_axi_req.aw.user;
assign o_bus_axi_aw_valid  = w_bridge_axi_req.aw_valid;
assign w_bridge_axi_resp.aw_ready = i_bus_axi_aw_ready;

assign o_bus_axi_w_data  = w_bridge_axi_req.w.data;
assign o_bus_axi_w_strb  = w_bridge_axi_req.w.strb;
assign o_bus_axi_w_last  = w_bridge_axi_req.w.last;
assign o_bus_axi_w_user  = w_bridge_axi_req.w.user;
assign o_bus_axi_w_valid = w_bridge_axi_req.w_valid;
assign w_bridge_axi_resp.w_ready = i_bus_axi_w_ready;

assign o_bus_axi_b_ready = w_bridge_axi_req.b_ready;
assign w_bridge_axi_resp.b.id   = i_bus_axi_b_id;
assign w_bridge_axi_resp.b.resp = i_bus_axi_b_resp;
assign w_bridge_axi_resp.b.user = i_bus_axi_b_user;
assign w_bridge_axi_resp.b_valid = i_bus_axi_b_valid;

assign o_bus_axi_ar_id     = w_bridge_axi_req.ar.id;
assign o_bus_axi_ar_addr   = w_bridge_axi_req.ar.addr;
assign o_bus_axi_ar_len    = w_bridge_axi_req.ar.len;
assign o_bus_axi_ar_size   = w_bridge_axi_req.ar.size;
assign o_bus_axi_ar_burst  = w_bridge_axi_req.ar.burst;
assign o_bus_axi_ar_lock   = w_bridge_axi_req.ar.lock;
assign o_bus_axi_ar_cache  = w_bridge_axi_req.ar.cache;
assign o_bus_axi_ar_prot   = w_bridge_axi_req.ar.prot;
assign o_bus_axi_ar_qos    = w_bridge_axi_req.ar.qos;
assign o_bus_axi_ar_region = w_bridge_axi_req.ar.region;
assign o_bus_axi_ar_user   = w_bridge_axi_req.ar.user;
assign o_bus_axi_ar_valid  = w_bridge_axi_req.ar_valid;
assign w_bridge_axi_resp.ar_ready = i_bus_axi_ar_ready;

assign o_bus_axi_r_ready = w_bridge_axi_req.r_ready;
assign w_bridge_axi_resp.r.id   = i_bus_axi_r_id;
assign w_bridge_axi_resp.r.data = i_bus_axi_r_data;
assign w_bridge_axi_resp.r.resp = i_bus_axi_r_resp;
assign w_bridge_axi_resp.r.last = i_bus_axi_r_last;
assign w_bridge_axi_resp.r.user = i_bus_axi_r_user;
assign w_bridge_axi_resp.r_valid = i_bus_axi_r_valid;

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs_bridge.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: nil
// End:
