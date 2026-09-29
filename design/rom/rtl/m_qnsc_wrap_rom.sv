`timescale 1ns/1ps

// QNSC wrapper of m_vlsi_axi4_sram: the QSoC ROM, 2 KiB at 0x0000_0000 on
// S_BUS AXI_M0.
// Spec: doc/specs/QNSC_ROM_MAS.md.
//
// Edit this .src.sv, then `make wrap BLOCK=rom`: emacs verilog-mode expands
// the AUTO comments and writes rtl/m_qnsc_wrap_rom.sv, the file rom.f compiles.
// Template functions: doc/rules/EMACS_quick_guide.pdf.
//
// Declare no port by hand: map every IP port in the AUTO_TEMPLATE, bit slices
// included, so the AUTOs declare them. Then this file is valid SystemVerilog
// before expansion, and the editor shows no false errors.
//
// Wrapper = core + bridge. The core is the IP; the bridge, only when the IP
// speaks another protocol than the chip bus, converts it. The controller
// already speaks AXI4: no bridge.

// This wrapper is IP: it imports no chip package and declares no parameter.
module m_qnsc_wrap_rom
(
//---------------------------------------------------------------
// Clock/Reset: SCRC o_clk_rom, o_rst_n_rom (mem cluster, never gated)
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_mem,              // To u_sram_ctrl of m_vlsi_axi4_sram.v, ...
input logic             i_rst_n_mem,            // To u_sram_ctrl of m_vlsi_axi4_sram.v, ...
// End of automatics

//---------------------------------------------------------------
// Bus interface (AXI4 subordinate, S_BUS AXI_M0)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_axi")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [31:0]      i_bus_axi_ar_addr,      // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [1:0]       i_bus_axi_ar_burst,     // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [6:0]       i_bus_axi_ar_id,        // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [7:0]       i_bus_axi_ar_len,       // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic             i_bus_axi_ar_valid,     // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [31:0]      i_bus_axi_aw_addr,      // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic [1:0]       i_bus_axi_aw_burst,     // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic [6:0]       i_bus_axi_aw_id,        // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic [7:0]       i_bus_axi_aw_len,       // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic             i_bus_axi_aw_valid,     // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic             i_bus_axi_b_ready,      // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic             i_bus_axi_r_ready,      // To u_sram_ctrl of m_vlsi_axi4_sram.v
input logic [31:0]      i_bus_axi_w_data,       // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic             i_bus_axi_w_last,       // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic [3:0]       i_bus_axi_w_strb,       // To u_wr_resp of m_qnsc_rom_wr_resp.v
input logic             i_bus_axi_w_valid,      // To u_wr_resp of m_qnsc_rom_wr_resp.v
// End of automatics
/*AUTOOUTPUT("^o_bus_axi")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic            o_bus_axi_ar_ready,     // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_aw_ready,     // From u_wr_resp of m_qnsc_rom_wr_resp.v
output logic [6:0]      o_bus_axi_b_id,         // From u_wr_resp of m_qnsc_rom_wr_resp.v
output logic [1:0]      o_bus_axi_b_resp,       // From u_wr_resp of m_qnsc_rom_wr_resp.v
output logic            o_bus_axi_b_valid,      // From u_wr_resp of m_qnsc_rom_wr_resp.v
output logic [31:0]     o_bus_axi_r_data,       // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic [6:0]      o_bus_axi_r_id,         // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_r_last,       // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic [1:0]      o_bus_axi_r_resp,       // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_r_valid,      // From u_sram_ctrl of m_vlsi_axi4_sram.v
output logic            o_bus_axi_w_ready      // From u_wr_resp of m_qnsc_rom_wr_resp.v
// End of automatics

//---------------------------------------------------------------
// Others -- must stay empty once the templates below are complete
//---------------------------------------------------------------
/*AUTOINOUT*/
/*AUTOINPUT*/
/*AUTOOUTPUT*/
);

/*AUTOWIRE*/
// Beginning of automatic wires (for undeclared instantiated-module outputs)
logic [31:0]            w_mem_addr;             // From u_sram_ctrl of m_vlsi_axi4_sram.v
logic                   w_mem_oe;               // From u_sram_ctrl of m_vlsi_axi4_sram.v
logic [31:0]            w_mem_rdata;            // From u_rom_image of m_qnsc_rom_image.v
// End of automatics

//---------------------------------------------------------------
// Integration policy (QNSC_ROM_MAS 3, 7, 10)
//---------------------------------------------------------------
// The libraries have no mask ROM and no OTP, so the ROM is the RAM's AXI
// controller in front of a constant image generated from the bootloader:
//
//   AR/R   -> m_vlsi_axi4_sram (vendored, not modified), write channel tied
//             idle; o_sram_oe / o_sram_addr[10:2] -> m_qnsc_rom_image
//             (generated by util/gen_rom.py)
//   AW/W/B -> m_qnsc_rom_wr_resp: every write answered with SLVERR (7.3)
//
// The controller has the parameters of ISRAM and DSRAM, so QNSC_RAM_MAS 7.1,
// 7.2, 7.4 and 7.6 apply to the read path unchanged: RVALID 4 cycles after AR,
// one beat every 2 cycles, one read in flight, RRESP = OKAY. Address bits above
// [10:2] are ignored: an INCR burst past 0x7FF wraps to word 0 (accepted limit,
// MAS 7.1).

/*AUTO_LISP(setq verilog-auto-inout-ignore-regexp
  (concat
  "unuse_inout"
  "\\|unuse_inout"
  ))
*/

/*AUTO_LISP(setq verilog-auto-input-ignore-regexp
  (concat
  "^w_"
  "\\|unuse_input"
  ))
*/

/*AUTO_LISP(setq verilog-auto-output-ignore-regexp
  (concat
  "^w_"
  "\\|unuse_output"
  ))
*/

// Map every IP port to a QNSC name. First match wins; [] keeps the width.
// Write channel: inputs tied idle, outputs open (MAS Table 10-1); the write
// path is m_qnsc_rom_wr_resp below.
/* m_vlsi_axi4_sram AUTO_TEMPLATE(
    .i_clk                  (i_clk_mem),
    .i_rst_n                (i_rst_n_mem),
    .i_bready               (1'b1),
    .i_\(aw\|w\)\(.*\)      ('0),
    .o_\(aw\|w\|b\)\(.*\)   (),
    .i_ar\(.*\)             (i_bus_axi_ar_\1[]),
    .o_ar\(.*\)             (o_bus_axi_ar_\1[]),
    .o_r\(.*\)              (o_bus_axi_r_\1[]),
    .i_rready               (i_bus_axi_r_ready),
    .o_sram_oe              (w_mem_oe),
    .o_sram_addr            (w_mem_addr[]),
    .i_sram_rdata           (w_mem_rdata[]),
    .o_sram_\(wdata\|we\)   (),
);
*/
m_vlsi_axi4_sram #(  // naming-check: ignore -- vendored module name
  .PARA_DATA_WD    (32), // contract: meta.data_width
  .PARA_ADDR_WD    (32), // contract: meta.addr_width
  .PARA_ID_WD      (7),  // as ISRAM and DSRAM, QNSC_RAM_MAS Table 5-2
  .PARA_LEN_WD     (8),
  .PARA_FIFO_DEPTH (8)
) u_sram_ctrl (/*AUTOINST*/
               // Outputs
               .o_awready               (),                      // Templated
               .o_wready                (),                      // Templated
               .o_bid                   (),                      // Templated
               .o_bresp                 (),                      // Templated
               .o_bvalid                (),                      // Templated
               .o_arready               (o_bus_axi_ar_ready),    // Templated
               .o_rid                   (o_bus_axi_r_id[6:0]),   // Templated
               .o_rdata                 (o_bus_axi_r_data[31:0]), // Templated
               .o_rresp                 (o_bus_axi_r_resp[1:0]), // Templated
               .o_rvalid                (o_bus_axi_r_valid),     // Templated
               .o_rlast                 (o_bus_axi_r_last),      // Templated
               .o_sram_addr             (w_mem_addr[31:0]),      // Templated
               .o_sram_wdata            (),                      // Templated
               .o_sram_we               (),                      // Templated
               .o_sram_oe               (w_mem_oe),              // Templated
               // Inputs
               .i_clk                   (i_clk_mem),             // Templated
               .i_rst_n                 (i_rst_n_mem),           // Templated
               .i_awaddr                ('0),                    // Templated
               .i_awvalid               ('0),                    // Templated
               .i_awburst               ('0),                    // Templated
               .i_awlen                 ('0),                    // Templated
               .i_awid                  ('0),                    // Templated
               .i_wdata                 ('0),                    // Templated
               .i_wvalid                ('0),                    // Templated
               .i_wlast                 ('0),                    // Templated
               .i_bready                (1'b1),                  // Templated
               .i_araddr                (i_bus_axi_ar_addr[31:0]), // Templated
               .i_arvalid               (i_bus_axi_ar_valid),    // Templated
               .i_arburst               (i_bus_axi_ar_burst[1:0]), // Templated
               .i_arlen                 (i_bus_axi_ar_len[7:0]), // Templated
               .i_arid                  (i_bus_axi_ar_id[6:0]),  // Templated
               .i_rready                (i_bus_axi_r_ready),     // Templated
               .i_sram_rdata            (w_mem_rdata[31:0]));     // Templated

// The controller's o_sram_addr is a byte address; the image takes the word
// index, 512 words = 2 KiB.
/* m_qnsc_rom_image AUTO_TEMPLATE(
    .i_mem_oe               (w_mem_oe),
    .i_mem_addr             (w_mem_addr[10:2]),
    .o_mem_rdata            (w_mem_rdata[]),
);
*/
m_qnsc_rom_image u_rom_image (/*AUTOINST*/
                              // Outputs
                              .o_mem_rdata      (w_mem_rdata[31:0]), // Templated
                              // Inputs
                              .i_clk_mem        (i_clk_mem),
                              .i_mem_oe         (w_mem_oe),      // Templated
                              .i_mem_addr       (w_mem_addr[10:2])); // Templated

// Ports named as the wrapper's: connected by name, no template.
m_qnsc_rom_wr_resp u_wr_resp (/*AUTOINST*/
                              // Outputs
                              .o_bus_axi_aw_ready(o_bus_axi_aw_ready),
                              .o_bus_axi_w_ready(o_bus_axi_w_ready),
                              .o_bus_axi_b_id   (o_bus_axi_b_id[6:0]),
                              .o_bus_axi_b_resp (o_bus_axi_b_resp[1:0]),
                              .o_bus_axi_b_valid(o_bus_axi_b_valid),
                              // Inputs
                              .i_clk_mem        (i_clk_mem),
                              .i_rst_n_mem      (i_rst_n_mem),
                              .i_bus_axi_aw_addr(i_bus_axi_aw_addr[31:0]),
                              .i_bus_axi_aw_valid(i_bus_axi_aw_valid),
                              .i_bus_axi_aw_burst(i_bus_axi_aw_burst[1:0]),
                              .i_bus_axi_aw_len (i_bus_axi_aw_len[7:0]),
                              .i_bus_axi_aw_id  (i_bus_axi_aw_id[6:0]),
                              .i_bus_axi_w_data (i_bus_axi_w_data[31:0]),
                              .i_bus_axi_w_strb (i_bus_axi_w_strb[3:0]),
                              .i_bus_axi_w_valid(i_bus_axi_w_valid),
                              .i_bus_axi_w_last (i_bus_axi_w_last),
                              .i_bus_axi_b_ready(i_bus_axi_b_ready));

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
