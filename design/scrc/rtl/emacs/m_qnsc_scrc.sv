`timescale 1ns/1ps

// =============================================================================
// m_qnsc_scrc -- System Clock and Reset Controller.
// Spec: `QNSC_SCRC_MAS` V3.4 on the team SharePoint.
//
// Edit this .src.sv, then `make wrap BLOCK=scrc`: emacs verilog-mode expands the
// AUTO comments and writes rtl/m_qnsc_scrc.sv, the file scrc.f compiles. No port
// is declared by hand and the level holds instances only; its one piece of logic,
// the bit map to the guards, is m_qnsc_scrc_map.
//
//   i_rst_n_pad -> qnsc_rst_filter -> qnsc_rst_sync -> o_rst_n_por -> RRC -> w_rst_n_sys
//   i_clk_pad   -> qnsc_clk_buf -> w_clk_root -> 18 x CTRL (gate + reset sync)
//                                                -> o_clk_<d>, o_rst_n_<d>
//   MCPU + CRM ROM -> WF (MCPU) -\
//                                 > APB BUS (generated) -> SCRC CSR (generated)
//   P_BUS APB_M0   -> WF (IBEX) -/                         -> map -> o_guard_blk
//
// Sequencing is software: MCPU is the only agent that opens a clock gate
// (ICG_EN), releases a reset (RST_REL) or opens an APB guard (APB_BLK). Ibex only
// writes requests (SW_RST, CLK_EN). No register field has two writers.
//
// Domain bits (MAS Table 6-3), shared with SYSCSR DOMAIN_RST_STATUS:
//   0 sbus  1 pbus  2 wdt  3 timer_0  4 timer_1  5 uart_0  6 uart_1  7 spi
//   8 i2c  9 gpio_0  10 dma  11 rom  12 ram  13 -  14 sysdbg  15 pwm
//   16 gpio_1  17 gpio_2  31 cpu
//   always-on (gate enable tied 1): cpu sbus pbus rom ram sysdbg wdt
//   gateable (CLK_EN/ICG_EN/APB_BLK/APB_BUSY bit, guard): 0x0003_87F8
// =============================================================================
module m_qnsc_scrc
(
//---------------------------------------------------------------
// Dedicated pads: CLKIN (20 MHz root clock), PORSTN (power-on reset)
//---------------------------------------------------------------
/*AUTOINPUT("^i_clk\|^i_rst")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_clk_pad,              // To u_clk_buf of qnsc_clk_buf.v
input logic             i_rst_n_pad,            // To u_rst_filter of qnsc_rst_filter.v
// End of automatics

//---------------------------------------------------------------
// Reset request: WDT aon_timer_rst_req_o (sticky, WDT domain)
//---------------------------------------------------------------
/*AUTOINPUT("^i_wdt")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic             i_wdt_rst_req,          // To u_rrc of m_qnsc_scrc_rrc.v
// End of automatics

//---------------------------------------------------------------
// P_BUS APB_M0 (Ibex). PPROT is not checked (no privilege check, MAS 10)
//---------------------------------------------------------------
/*AUTOINPUT("^i_bus_apb")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [13:0]      i_bus_apb_paddr,        // To u_wf_ibex of m_qnsc_scrc_apb_wfilter.v, ...
input logic             i_bus_apb_penable,      // To u_wf_ibex of m_qnsc_scrc_apb_wfilter.v
input logic [2:0]       i_bus_apb_pprot,        // To u_apb_bus of m_qnsc_scrc_apb_bus.v
input logic             i_bus_apb_psel,         // To u_wf_ibex of m_qnsc_scrc_apb_wfilter.v
input logic [3:0]       i_bus_apb_pstrb,        // To u_apb_bus of m_qnsc_scrc_apb_bus.v
input logic [31:0]      i_bus_apb_pwdata,       // To u_apb_bus of m_qnsc_scrc_apb_bus.v
input logic             i_bus_apb_pwrite,       // To u_wf_ibex of m_qnsc_scrc_apb_wfilter.v, ...
// End of automatics
/*AUTOOUTPUT("^o_bus_apb")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [31:0]     o_bus_apb_prdata,       // From u_wf_ibex of m_qnsc_scrc_apb_wfilter.v
output logic            o_bus_apb_pready,       // From u_wf_ibex of m_qnsc_scrc_apb_wfilter.v
output logic            o_bus_apb_pslverr,      // From u_wf_ibex of m_qnsc_scrc_apb_wfilter.v
// End of automatics

//---------------------------------------------------------------
// The 11 APB guards in design/top
//---------------------------------------------------------------
/*AUTOINPUT("^i_guard")*/
// Beginning of automatic inputs (from unused autoinst inputs)
input logic [17:0]      i_guard_busy,           // To u_map of m_qnsc_scrc_map.v
// End of automatics
/*AUTOOUTPUT("^o_guard")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic [17:0]     o_guard_blk,            // From u_map of m_qnsc_scrc_map.v
// End of automatics

//---------------------------------------------------------------
// Domain clocks and resets (MAS Table 5-2), and o_rst_n_por: the
// synchronised power-on reset, not affected by WDT or SW (to SYSCSR, SYSDBG)
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_clk_\|^o_rst_n_")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic            o_clk_cpu,              // From u_ctrl_cpu of m_qnsc_scrc_ctrl.v
output logic            o_clk_dma,              // From u_ctrl_dma of m_qnsc_scrc_ctrl.v
output logic            o_clk_gpio_0,           // From u_ctrl_gpio_0 of m_qnsc_scrc_ctrl.v
output logic            o_clk_gpio_1,           // From u_ctrl_gpio_1 of m_qnsc_scrc_ctrl.v
output logic            o_clk_gpio_2,           // From u_ctrl_gpio_2 of m_qnsc_scrc_ctrl.v
output logic            o_clk_i2c,              // From u_ctrl_i2c of m_qnsc_scrc_ctrl.v
output logic            o_clk_pbus,             // From u_ctrl_pbus of m_qnsc_scrc_ctrl.v
output logic            o_clk_pwm,              // From u_ctrl_pwm of m_qnsc_scrc_ctrl.v
output logic            o_clk_ram,              // From u_ctrl_ram of m_qnsc_scrc_ctrl.v
output logic            o_clk_rom,              // From u_ctrl_rom of m_qnsc_scrc_ctrl.v
output logic            o_clk_sbus,             // From u_ctrl_sbus of m_qnsc_scrc_ctrl.v
output logic            o_clk_spi,              // From u_ctrl_spi of m_qnsc_scrc_ctrl.v
output logic            o_clk_sysdbg,           // From u_ctrl_sysdbg of m_qnsc_scrc_ctrl.v
output logic            o_clk_timer_0,          // From u_ctrl_timer_0 of m_qnsc_scrc_ctrl.v
output logic            o_clk_timer_1,          // From u_ctrl_timer_1 of m_qnsc_scrc_ctrl.v
output logic            o_clk_uart_0,           // From u_ctrl_uart_0 of m_qnsc_scrc_ctrl.v
output logic            o_clk_uart_1,           // From u_ctrl_uart_1 of m_qnsc_scrc_ctrl.v
output logic            o_clk_wdt,              // From u_ctrl_wdt of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_cpu,            // From u_ctrl_cpu of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_dma,            // From u_ctrl_dma of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_gpio_0,         // From u_ctrl_gpio_0 of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_gpio_1,         // From u_ctrl_gpio_1 of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_gpio_2,         // From u_ctrl_gpio_2 of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_i2c,            // From u_ctrl_i2c of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_pbus,           // From u_ctrl_pbus of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_pwm,            // From u_ctrl_pwm of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_ram,            // From u_ctrl_ram of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_rom,            // From u_ctrl_rom of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_sbus,           // From u_ctrl_sbus of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_spi,            // From u_ctrl_spi of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_sysdbg,         // From u_ctrl_sysdbg of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_timer_0,        // From u_ctrl_timer_0 of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_timer_1,        // From u_ctrl_timer_1 of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_uart_0,         // From u_ctrl_uart_0 of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_uart_1,         // From u_ctrl_uart_1 of m_qnsc_scrc_ctrl.v
output logic            o_rst_n_wdt,            // From u_ctrl_wdt of m_qnsc_scrc_ctrl.v
// End of automatics
/*AUTOOUTPUTEVERY("^o_rst_n_por")*/
// Beginning of automatic outputs (every signal)
output logic            o_rst_n_por,            // From u_rst_sync_por of qnsc_rst_sync.v
// End of automatics

//---------------------------------------------------------------
// To SYSCSR: cause enables, 1 while a WDT / SW chip reset lasts
//---------------------------------------------------------------
/*AUTOOUTPUT("^o_cause")*/
// Beginning of automatic outputs (from unused autoinst outputs)
output logic            o_cause_we_sw,          // From u_rrc of m_qnsc_scrc_rrc.v
output logic            o_cause_we_wdt         // From u_rrc of m_qnsc_scrc_rrc.v
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
wire                    w_blk_dma;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_gpio_0;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_gpio_1;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_gpio_2;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_i2c;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_pwm;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_spi;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_timer_0;          // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_timer_1;          // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_uart_0;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_blk_uart_1;           // From u_csr of m_qnsc_scrc_csr.v
logic                   w_busy_dma;             // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_gpio_0;          // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_gpio_1;          // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_gpio_2;          // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_i2c;             // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_pwm;             // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_spi;             // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_timer_0;         // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_timer_1;         // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_uart_0;          // From u_map of m_qnsc_scrc_map.v
logic                   w_busy_uart_1;          // From u_map of m_qnsc_scrc_map.v
logic                   w_clk_root;             // From u_clk_buf of qnsc_clk_buf.v
logic [4:0]             w_csr_paddr;            // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_csr_penable;          // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic [2:0]             w_csr_pprot;            // From u_apb_bus of m_qnsc_scrc_apb_bus.v
wire [31:0]             w_csr_prdata;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_csr_pready;           // From u_csr of m_qnsc_scrc_csr.v
logic                   w_csr_protect_en;       // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_csr_psel;             // From u_apb_bus of m_qnsc_scrc_apb_bus.v
wire                    w_csr_pslverr;          // From u_csr of m_qnsc_scrc_csr.v
logic [3:0]             w_csr_pstrb;            // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic [31:0]            w_csr_pwdata;           // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_csr_pwrite;           // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_csr_slverr_en;        // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_ibex_fwd_penable;     // From u_wf_ibex of m_qnsc_scrc_apb_wfilter.v
logic [31:0]            w_ibex_fwd_prdata;      // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_ibex_fwd_pready;      // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_ibex_fwd_psel;        // From u_wf_ibex of m_qnsc_scrc_apb_wfilter.v
logic                   w_ibex_fwd_pslverr;     // From u_apb_bus of m_qnsc_scrc_apb_bus.v
wire                    w_icg_dma;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_gpio_0;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_gpio_1;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_gpio_2;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_i2c;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_pwm;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_spi;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_timer_0;          // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_timer_1;          // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_uart_0;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_icg_uart_1;           // From u_csr of m_qnsc_scrc_csr.v
logic                   w_mcpu_fwd_penable;     // From u_wf_mcpu of m_qnsc_scrc_apb_wfilter.v
logic [31:0]            w_mcpu_fwd_prdata;      // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_mcpu_fwd_pready;      // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic                   w_mcpu_fwd_psel;        // From u_wf_mcpu of m_qnsc_scrc_apb_wfilter.v
logic                   w_mcpu_fwd_pslverr;     // From u_apb_bus of m_qnsc_scrc_apb_bus.v
logic [31:0]            w_mcpu_imem_addr;       // From u_mcpu of m_vlsit_mrv_cpu.v
logic [31:0]            w_mcpu_imem_data;       // From u_crm_rom of m_qnsc_scrc_crm_rom.v
logic [31:0]            w_mcpu_paddr;           // From u_mcpu of m_vlsit_mrv_cpu.v
logic                   w_mcpu_penable;         // From u_mcpu of m_vlsit_mrv_cpu.v
logic [31:0]            w_mcpu_prdata;          // From u_wf_mcpu of m_qnsc_scrc_apb_wfilter.v
logic                   w_mcpu_pready;          // From u_wf_mcpu of m_qnsc_scrc_apb_wfilter.v
logic                   w_mcpu_psel;            // From u_mcpu of m_vlsit_mrv_cpu.v
logic                   w_mcpu_pslverr;         // From u_wf_mcpu of m_qnsc_scrc_apb_wfilter.v
logic [31:0]            w_mcpu_pwdata;          // From u_mcpu of m_vlsit_mrv_cpu.v
logic                   w_mcpu_pwrite;          // From u_mcpu of m_vlsit_mrv_cpu.v
wire                    w_rel_cpu;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_dma;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_gpio_0;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_gpio_1;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_gpio_2;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_i2c;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_pbus;             // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_pwm;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_ram;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_rom;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_sbus;             // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_spi;              // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_timer_0;          // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_timer_1;          // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_uart_0;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_uart_1;           // From u_csr of m_qnsc_scrc_csr.v
wire                    w_rel_wdt;              // From u_csr of m_qnsc_scrc_csr.v
logic                   w_rst_n_filt;           // From u_rst_filter of qnsc_rst_filter.v
logic                   w_rst_n_sys;            // From u_rrc of m_qnsc_scrc_rrc.v
wire                    w_sw_rst;               // From u_csr of m_qnsc_scrc_csr.v
// End of automatics

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

//---------------------------------------------------------------
// 1. Root clock and power-on input stage (MAS 7.1, 7.2). Technology cells.
//---------------------------------------------------------------
/* qnsc_clk_buf AUTO_TEMPLATE(
    .i_clk_src      (i_clk_pad),
    .o_clk_buf      (w_clk_root),
);
*/
qnsc_clk_buf u_clk_buf (/*AUTOINST*/
                        // Outputs
                        .o_clk_buf      (w_clk_root),            // Templated
                        // Inputs
                        .i_clk_src      (i_clk_pad));             // Templated

/* qnsc_rst_filter AUTO_TEMPLATE(
    .i_rst_n_raw    (i_rst_n_pad),
    .o_rst_n_filt   (w_rst_n_filt),
);
*/
qnsc_rst_filter u_rst_filter (/*AUTOINST*/
                              // Outputs
                              .o_rst_n_filt     (w_rst_n_filt),  // Templated
                              // Inputs
                              .i_rst_n_raw      (i_rst_n_pad));   // Templated

// Scan enable tied 0: no scan in QSOC v1 (MAS 10).
/* qnsc_rst_sync AUTO_TEMPLATE(
    .i_clk_dst      (w_clk_root),
    .i_rst_n_src    (w_rst_n_filt),
    .i_dft_scan_en  (1'b0),
    .o_rst_n_dst    (o_rst_n_por),
);
*/
qnsc_rst_sync u_rst_sync_por (/*AUTOINST*/
                              // Outputs
                              .o_rst_n_dst      (o_rst_n_por),   // Templated
                              // Inputs
                              .i_clk_dst        (w_clk_root),    // Templated
                              .i_rst_n_src      (w_rst_n_filt),  // Templated
                              .i_dft_scan_en    (1'b0));          // Templated

//---------------------------------------------------------------
// 2. Reset Request Controller (MAS 7.3)
//---------------------------------------------------------------
/* m_qnsc_scrc_rrc AUTO_TEMPLATE(
    .i_clk_root     (w_clk_root),
    .i_rst_n_por    (o_rst_n_por),
    .i_sw_rst       (w_sw_rst),
    .o_rst_n_sys    (w_rst_n_sys),
);
*/
m_qnsc_scrc_rrc u_rrc (/*AUTOINST*/
                       // Outputs
                       .o_rst_n_sys     (w_rst_n_sys),           // Templated
                       .o_cause_we_wdt  (o_cause_we_wdt),
                       .o_cause_we_sw   (o_cause_we_sw),
                       // Inputs
                       .i_clk_root      (w_clk_root),            // Templated
                       .i_rst_n_por     (o_rst_n_por),           // Templated
                       .i_wdt_rst_req   (i_wdt_rst_req),
                       .i_sw_rst        (w_sw_rst));              // Templated

//---------------------------------------------------------------
// 3. MCPU and CRM ROM (MAS 7.5, 7.6). Polling only: i_interrupt tied 0.
//---------------------------------------------------------------
/* m_vlsit_mrv_cpu AUTO_TEMPLATE(
    .i_clk          (w_clk_root),
    .i_rst_n        (w_rst_n_sys),
    .i_interrupt    (1'b0),
    .o_imem_\(.*\)  (w_mcpu_imem_\1[]),
    .i_imem_\(.*\)  (w_mcpu_imem_\1[]),
    .o_p\(.*\)      (w_mcpu_p\1[]),
    .i_p\(.*\)      (w_mcpu_p\1[]),
);
*/
m_vlsit_mrv_cpu #(  // naming-check: ignore -- vendored module name
  .PARA_RESET_VECTOR (32'h0000_1000),  // hardcode-check: ignore -- MRV reset vector, the CRM ROM base, not an address of the chip map
  .PARA_INT_VECTOR   (12'h100)         // naming-check: ignore -- parameter of a vendored module; not used, i_interrupt tied 0
) u_mcpu (/*AUTOINST*/
          // Outputs
          .o_imem_addr                  (w_mcpu_imem_addr[31:0]), // Templated
          .o_paddr                      (w_mcpu_paddr[31:0]),    // Templated
          .o_pwdata                     (w_mcpu_pwdata[31:0]),   // Templated
          .o_pwrite                     (w_mcpu_pwrite),         // Templated
          .o_psel                       (w_mcpu_psel),           // Templated
          .o_penable                    (w_mcpu_penable),        // Templated
          // Inputs
          .i_clk                        (w_clk_root),            // Templated
          .i_rst_n                      (w_rst_n_sys),           // Templated
          .i_interrupt                  (1'b0),                  // Templated
          .i_imem_data                  (w_mcpu_imem_data[31:0]), // Templated
          .i_prdata                     (w_mcpu_prdata[31:0]),   // Templated
          .i_pready                     (w_mcpu_pready));         // Templated

/* m_qnsc_scrc_crm_rom AUTO_TEMPLATE(
    .i_imem_addr    (w_mcpu_imem_addr[]),
    .o_imem_data    (w_mcpu_imem_data[]),
);
*/
m_qnsc_scrc_crm_rom u_crm_rom (/*AUTOINST*/
                               // Outputs
                               .o_imem_data     (w_mcpu_imem_data[31:0]), // Templated
                               // Inputs
                               .i_imem_addr     (w_mcpu_imem_addr[31:0])); // Templated

//---------------------------------------------------------------
// 4. Write filters (MAS 7.4, Table 7-2). Offset = PADDR[13:0].
//---------------------------------------------------------------
/* m_qnsc_scrc_apb_wfilter AUTO_TEMPLATE(
    .i_bus_apb_s_0_paddr    (w_mcpu_paddr[13:0]),
    .\([io]\)_bus_apb_s_0_\(.*\)  (w_mcpu_\2[]),
    .\([io]\)_bus_apb_m_0_\(.*\)  (w_mcpu_fwd_\2[]),
);
*/
m_qnsc_scrc_apb_wfilter #(.P_WR_DENY(8'b0100_0011)) u_wf_mcpu (/*AUTOINST*/
                                                               // Outputs
                                                               .o_bus_apb_s_0_pready(w_mcpu_pready), // Templated
                                                               .o_bus_apb_s_0_pslverr(w_mcpu_pslverr), // Templated
                                                               .o_bus_apb_s_0_prdata(w_mcpu_prdata[31:0]), // Templated
                                                               .o_bus_apb_m_0_psel(w_mcpu_fwd_psel), // Templated
                                                               .o_bus_apb_m_0_penable(w_mcpu_fwd_penable), // Templated
                                                               // Inputs
                                                               .i_bus_apb_s_0_psel(w_mcpu_psel), // Templated
                                                               .i_bus_apb_s_0_penable(w_mcpu_penable), // Templated
                                                               .i_bus_apb_s_0_pwrite(w_mcpu_pwrite), // Templated
                                                               .i_bus_apb_s_0_paddr(w_mcpu_paddr[13:0]), // Templated
                                                               .i_bus_apb_m_0_pready(w_mcpu_fwd_pready), // Templated
                                                               .i_bus_apb_m_0_pslverr(w_mcpu_fwd_pslverr), // Templated
                                                               .i_bus_apb_m_0_prdata(w_mcpu_fwd_prdata[31:0])); // Templated

/* m_qnsc_scrc_apb_wfilter AUTO_TEMPLATE(
    .\([io]\)_bus_apb_s_0_\(.*\)  (\1_bus_apb_\2[]),
    .\([io]\)_bus_apb_m_0_\(.*\)  (w_ibex_fwd_\2[]),
);
*/
m_qnsc_scrc_apb_wfilter #(.P_WR_DENY(8'b0111_1000)) u_wf_ibex (/*AUTOINST*/
                                                               // Outputs
                                                               .o_bus_apb_s_0_pready(o_bus_apb_pready), // Templated
                                                               .o_bus_apb_s_0_pslverr(o_bus_apb_pslverr), // Templated
                                                               .o_bus_apb_s_0_prdata(o_bus_apb_prdata[31:0]), // Templated
                                                               .o_bus_apb_m_0_psel(w_ibex_fwd_psel), // Templated
                                                               .o_bus_apb_m_0_penable(w_ibex_fwd_penable), // Templated
                                                               // Inputs
                                                               .i_bus_apb_s_0_psel(i_bus_apb_psel), // Templated
                                                               .i_bus_apb_s_0_penable(i_bus_apb_penable), // Templated
                                                               .i_bus_apb_s_0_pwrite(i_bus_apb_pwrite), // Templated
                                                               .i_bus_apb_s_0_paddr(i_bus_apb_paddr[13:0]), // Templated
                                                               .i_bus_apb_m_0_pready(w_ibex_fwd_pready), // Templated
                                                               .i_bus_apb_m_0_pslverr(w_ibex_fwd_pslverr), // Templated
                                                               .i_bus_apb_m_0_prdata(w_ibex_fwd_prdata[31:0])); // Templated

//---------------------------------------------------------------
// 5. APB BUS (util/gen/scrc_bus): masters MCPU, IBEX; slave SCRC_CSR at
//    0x00-0x1F; 0x0020-0x3FFF answered with PSLVERR. MCPU has no PSTRB or
//    PPROT (MAS Table 10-1).
//---------------------------------------------------------------
/* m_qnsc_scrc_apb_bus AUTO_TEMPLATE(
    .i_clk                          (w_clk_root),
    .i_rstn                         (w_rst_n_sys),
    .i_paddr_mcpu                   (w_mcpu_paddr[13:0]),
    .i_protect_en_\(mcpu\|ibex\)    (1'b0),
    .i_slverr_en_\(mcpu\|ibex\)     (1'b1),
    .i_pprot_mcpu                   (3'b000),
    .i_pstrb_mcpu                   (4'hF),
    .i_\(penable\|psel\)_\(mcpu\|ibex\)  (w_\2_fwd_\1),
    .o_\(.*\)_\(mcpu\|ibex\)        (w_\2_fwd_\1[]),
    .i_\(.*\)_mcpu                  (w_mcpu_\1[]),
    .i_\(.*\)_ibex                  (i_bus_apb_\1[]),
    .\([io]\)_\(.*\)_scrc_csr       (w_csr_\2[]),
);
*/
m_qnsc_scrc_apb_bus u_apb_bus (/*AUTOINST*/
                               // Outputs
                               .o_pslverr_mcpu  (w_mcpu_fwd_pslverr), // Templated
                               .o_pready_mcpu   (w_mcpu_fwd_pready), // Templated
                               .o_prdata_mcpu   (w_mcpu_fwd_prdata[31:0]), // Templated
                               .o_pslverr_ibex  (w_ibex_fwd_pslverr), // Templated
                               .o_pready_ibex   (w_ibex_fwd_pready), // Templated
                               .o_prdata_ibex   (w_ibex_fwd_prdata[31:0]), // Templated
                               .o_paddr_scrc_csr(w_csr_paddr[4:0]), // Templated
                               .o_protect_en_scrc_csr(w_csr_protect_en), // Templated
                               .o_slverr_en_scrc_csr(w_csr_slverr_en), // Templated
                               .o_pprot_scrc_csr(w_csr_pprot[2:0]), // Templated
                               .o_pwdata_scrc_csr(w_csr_pwdata[31:0]), // Templated
                               .o_pwrite_scrc_csr(w_csr_pwrite), // Templated
                               .o_penable_scrc_csr(w_csr_penable), // Templated
                               .o_psel_scrc_csr (w_csr_psel),    // Templated
                               .o_pstrb_scrc_csr(w_csr_pstrb[3:0]), // Templated
                               // Inputs
                               .i_clk           (w_clk_root),    // Templated
                               .i_rstn          (w_rst_n_sys),   // Templated
                               .i_paddr_mcpu    (w_mcpu_paddr[13:0]), // Templated
                               .i_protect_en_mcpu(1'b0),         // Templated
                               .i_slverr_en_mcpu(1'b1),          // Templated
                               .i_pprot_mcpu    (3'b000),        // Templated
                               .i_pwdata_mcpu   (w_mcpu_pwdata[31:0]), // Templated
                               .i_pwrite_mcpu   (w_mcpu_pwrite), // Templated
                               .i_penable_mcpu  (w_mcpu_fwd_penable), // Templated
                               .i_psel_mcpu     (w_mcpu_fwd_psel), // Templated
                               .i_pstrb_mcpu    (4'hF),          // Templated
                               .i_paddr_ibex    (i_bus_apb_paddr[13:0]), // Templated
                               .i_protect_en_ibex(1'b0),         // Templated
                               .i_slverr_en_ibex(1'b1),          // Templated
                               .i_pprot_ibex    (i_bus_apb_pprot[2:0]), // Templated
                               .i_pwdata_ibex   (i_bus_apb_pwdata[31:0]), // Templated
                               .i_pwrite_ibex   (i_bus_apb_pwrite), // Templated
                               .i_penable_ibex  (w_ibex_fwd_penable), // Templated
                               .i_psel_ibex     (w_ibex_fwd_psel), // Templated
                               .i_pstrb_ibex    (i_bus_apb_pstrb[3:0]), // Templated
                               .i_pslverr_scrc_csr(w_csr_pslverr), // Templated
                               .i_pready_scrc_csr(w_csr_pready), // Templated
                               .i_prdata_scrc_csr(w_csr_prdata[31:0])); // Templated

//---------------------------------------------------------------
// 6. SCRC CSR (util/gen/scrc_csr; MAS 6). i_protect_en = 0 and
//    i_slverr_en = 1 come from the bus (MAS Table 10-1). CLK_EN is read by
//    MCPU over the bus; its field outputs are not used.
//---------------------------------------------------------------
/* m_qnsc_scrc_csr AUTO_TEMPLATE(
    .i_bus_clk                (w_clk_root),
    .i_bus_rstn               (w_rst_n_sys),
    .i_paddr                  ({11'd0, w_csr_paddr}),
    .o_swrst_sw_rst           (w_sw_rst),
    .o_clken_\(.*\)           (),
    .o_icgen_icg_\(.*\)       (w_icg_\1),
    .o_rstrel_rel_\(.*\)      (w_rel_\1),
    .o_apbblk_blk_\(.*\)      (w_blk_\1),
    .i_apbbusy_busy_\(.*\)    (w_busy_\1),
    .\([io]\)_\(.*\)          (w_csr_\2[]),
);
*/
m_qnsc_scrc_csr u_csr (/*AUTOINST*/
                       // Outputs
                       .o_pslverr       (w_csr_pslverr),         // Templated
                       .o_pready        (w_csr_pready),          // Templated
                       .o_prdata        (w_csr_prdata[31:0]),    // Templated
                       .o_swrst_sw_rst  (w_sw_rst),              // Templated
                       .o_clken_en_timer_0(),                    // Templated
                       .o_clken_en_timer_1(),                    // Templated
                       .o_clken_en_uart_0(),                     // Templated
                       .o_clken_en_uart_1(),                     // Templated
                       .o_clken_en_spi  (),                      // Templated
                       .o_clken_en_i2c  (),                      // Templated
                       .o_clken_en_gpio_0(),                     // Templated
                       .o_clken_en_dma  (),                      // Templated
                       .o_clken_en_pwm  (),                      // Templated
                       .o_clken_en_gpio_1(),                     // Templated
                       .o_clken_en_gpio_2(),                     // Templated
                       .o_icgen_icg_timer_0(w_icg_timer_0),      // Templated
                       .o_icgen_icg_timer_1(w_icg_timer_1),      // Templated
                       .o_icgen_icg_uart_0(w_icg_uart_0),        // Templated
                       .o_icgen_icg_uart_1(w_icg_uart_1),        // Templated
                       .o_icgen_icg_spi (w_icg_spi),             // Templated
                       .o_icgen_icg_i2c (w_icg_i2c),             // Templated
                       .o_icgen_icg_gpio_0(w_icg_gpio_0),        // Templated
                       .o_icgen_icg_dma (w_icg_dma),             // Templated
                       .o_icgen_icg_pwm (w_icg_pwm),             // Templated
                       .o_icgen_icg_gpio_1(w_icg_gpio_1),        // Templated
                       .o_icgen_icg_gpio_2(w_icg_gpio_2),        // Templated
                       .o_rstrel_rel_sbus(w_rel_sbus),           // Templated
                       .o_rstrel_rel_pbus(w_rel_pbus),           // Templated
                       .o_rstrel_rel_wdt(w_rel_wdt),             // Templated
                       .o_rstrel_rel_timer_0(w_rel_timer_0),     // Templated
                       .o_rstrel_rel_timer_1(w_rel_timer_1),     // Templated
                       .o_rstrel_rel_uart_0(w_rel_uart_0),       // Templated
                       .o_rstrel_rel_uart_1(w_rel_uart_1),       // Templated
                       .o_rstrel_rel_spi(w_rel_spi),             // Templated
                       .o_rstrel_rel_i2c(w_rel_i2c),             // Templated
                       .o_rstrel_rel_gpio_0(w_rel_gpio_0),       // Templated
                       .o_rstrel_rel_dma(w_rel_dma),             // Templated
                       .o_rstrel_rel_rom(w_rel_rom),             // Templated
                       .o_rstrel_rel_ram(w_rel_ram),             // Templated
                       .o_rstrel_rel_pwm(w_rel_pwm),             // Templated
                       .o_rstrel_rel_gpio_1(w_rel_gpio_1),       // Templated
                       .o_rstrel_rel_gpio_2(w_rel_gpio_2),       // Templated
                       .o_rstrel_rel_cpu(w_rel_cpu),             // Templated
                       .o_apbblk_blk_timer_0(w_blk_timer_0),     // Templated
                       .o_apbblk_blk_timer_1(w_blk_timer_1),     // Templated
                       .o_apbblk_blk_uart_0(w_blk_uart_0),       // Templated
                       .o_apbblk_blk_uart_1(w_blk_uart_1),       // Templated
                       .o_apbblk_blk_spi(w_blk_spi),             // Templated
                       .o_apbblk_blk_i2c(w_blk_i2c),             // Templated
                       .o_apbblk_blk_gpio_0(w_blk_gpio_0),       // Templated
                       .o_apbblk_blk_dma(w_blk_dma),             // Templated
                       .o_apbblk_blk_pwm(w_blk_pwm),             // Templated
                       .o_apbblk_blk_gpio_1(w_blk_gpio_1),       // Templated
                       .o_apbblk_blk_gpio_2(w_blk_gpio_2),       // Templated
                       // Inputs
                       .i_bus_clk       (w_clk_root),            // Templated
                       .i_bus_rstn      (w_rst_n_sys),           // Templated
                       .i_paddr         ({11'd0, w_csr_paddr}),  // Templated
                       .i_protect_en    (w_csr_protect_en),      // Templated
                       .i_slverr_en     (w_csr_slverr_en),       // Templated
                       .i_pprot         (w_csr_pprot[2:0]),      // Templated
                       .i_pwdata        (w_csr_pwdata[31:0]),    // Templated
                       .i_pwrite        (w_csr_pwrite),          // Templated
                       .i_penable       (w_csr_penable),         // Templated
                       .i_psel          (w_csr_psel),            // Templated
                       .i_pstrb         (w_csr_pstrb[3:0]),      // Templated
                       .i_apbbusy_busy_timer_0(w_busy_timer_0),  // Templated
                       .i_apbbusy_busy_timer_1(w_busy_timer_1),  // Templated
                       .i_apbbusy_busy_uart_0(w_busy_uart_0),    // Templated
                       .i_apbbusy_busy_uart_1(w_busy_uart_1),    // Templated
                       .i_apbbusy_busy_spi(w_busy_spi),          // Templated
                       .i_apbbusy_busy_i2c(w_busy_i2c),          // Templated
                       .i_apbbusy_busy_gpio_0(w_busy_gpio_0),    // Templated
                       .i_apbbusy_busy_dma(w_busy_dma),          // Templated
                       .i_apbbusy_busy_pwm(w_busy_pwm),          // Templated
                       .i_apbbusy_busy_gpio_1(w_busy_gpio_1),    // Templated
                       .i_apbbusy_busy_gpio_2(w_busy_gpio_2));    // Templated

/* m_qnsc_scrc_map AUTO_TEMPLATE(
    .i_blk_\(.*\)             (w_blk_\1),
    .o_busy_\(.*\)            (w_busy_\1),
);
*/
m_qnsc_scrc_map u_map (/*AUTOINST*/
                       // Outputs
                       .o_guard_blk     (o_guard_blk[17:0]),
                       .o_busy_timer_0  (w_busy_timer_0),        // Templated
                       .o_busy_timer_1  (w_busy_timer_1),        // Templated
                       .o_busy_uart_0   (w_busy_uart_0),         // Templated
                       .o_busy_uart_1   (w_busy_uart_1),         // Templated
                       .o_busy_spi      (w_busy_spi),            // Templated
                       .o_busy_i2c      (w_busy_i2c),            // Templated
                       .o_busy_gpio_0   (w_busy_gpio_0),         // Templated
                       .o_busy_dma      (w_busy_dma),            // Templated
                       .o_busy_pwm      (w_busy_pwm),            // Templated
                       .o_busy_gpio_1   (w_busy_gpio_1),         // Templated
                       .o_busy_gpio_2   (w_busy_gpio_2),         // Templated
                       // Inputs
                       .i_blk_timer_0   (w_blk_timer_0),         // Templated
                       .i_blk_timer_1   (w_blk_timer_1),         // Templated
                       .i_blk_uart_0    (w_blk_uart_0),          // Templated
                       .i_blk_uart_1    (w_blk_uart_1),          // Templated
                       .i_blk_spi       (w_blk_spi),             // Templated
                       .i_blk_i2c       (w_blk_i2c),             // Templated
                       .i_blk_gpio_0    (w_blk_gpio_0),          // Templated
                       .i_blk_dma       (w_blk_dma),             // Templated
                       .i_blk_pwm       (w_blk_pwm),             // Templated
                       .i_blk_gpio_1    (w_blk_gpio_1),          // Templated
                       .i_blk_gpio_2    (w_blk_gpio_2),          // Templated
                       .i_guard_busy    (i_guard_busy[17:0]));

//---------------------------------------------------------------
// 7. Domain controllers (MAS 7.1, 7.8, Table 5-2). Gate enable = ICG_EN bit,
//    reset input = RST_REL bit, both named after the instance; the seven
//    always-on domains tie the gate enable to 1, sysdbg's reset input is the
//    power-on reset, so a debug session survives a WDT or SW reset.
//---------------------------------------------------------------
/* m_qnsc_scrc_ctrl AUTO_TEMPLATE "u_ctrl_\(.*\)" (
    .i_clk_root               (w_clk_root),
    .i_icg_en                 (w_icg_@),
    .i_rst_n_in               (w_rel_@),
    .o_clk_gated              (o_clk_@),
    .o_rst_n_sync             (o_rst_n_@),
);
*/
// ---- always-on ----------------------------------------------------------------
m_qnsc_scrc_ctrl u_ctrl_cpu     (.i_icg_en (1'b1), /*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_cpu),     // Templated
                                 .o_rst_n_sync          (o_rst_n_cpu),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_rst_n_in            (w_rel_cpu));     // Templated
m_qnsc_scrc_ctrl u_ctrl_sbus    (.i_icg_en (1'b1), /*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_sbus),    // Templated
                                 .o_rst_n_sync          (o_rst_n_sbus),  // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_rst_n_in            (w_rel_sbus));    // Templated
m_qnsc_scrc_ctrl u_ctrl_pbus    (.i_icg_en (1'b1), /*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_pbus),    // Templated
                                 .o_rst_n_sync          (o_rst_n_pbus),  // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_rst_n_in            (w_rel_pbus));    // Templated
m_qnsc_scrc_ctrl u_ctrl_wdt     (.i_icg_en (1'b1), /*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_wdt),     // Templated
                                 .o_rst_n_sync          (o_rst_n_wdt),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_rst_n_in            (w_rel_wdt));     // Templated
m_qnsc_scrc_ctrl u_ctrl_rom     (.i_icg_en (1'b1), /*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_rom),     // Templated
                                 .o_rst_n_sync          (o_rst_n_rom),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_rst_n_in            (w_rel_rom));     // Templated
m_qnsc_scrc_ctrl u_ctrl_ram     (.i_icg_en (1'b1), /*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_ram),     // Templated
                                 .o_rst_n_sync          (o_rst_n_ram),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_rst_n_in            (w_rel_ram));     // Templated
m_qnsc_scrc_ctrl u_ctrl_sysdbg  (.i_icg_en (1'b1), .i_rst_n_in (o_rst_n_por), /*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_sysdbg),  // Templated
                                 .o_rst_n_sync          (o_rst_n_sysdbg), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root));    // Templated
// ---- gateable -----------------------------------------------------------------
m_qnsc_scrc_ctrl u_ctrl_timer_0 (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_timer_0), // Templated
                                 .o_rst_n_sync          (o_rst_n_timer_0), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_timer_0), // Templated
                                 .i_rst_n_in            (w_rel_timer_0)); // Templated
m_qnsc_scrc_ctrl u_ctrl_timer_1 (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_timer_1), // Templated
                                 .o_rst_n_sync          (o_rst_n_timer_1), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_timer_1), // Templated
                                 .i_rst_n_in            (w_rel_timer_1)); // Templated
m_qnsc_scrc_ctrl u_ctrl_uart_0  (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_uart_0),  // Templated
                                 .o_rst_n_sync          (o_rst_n_uart_0), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_uart_0),  // Templated
                                 .i_rst_n_in            (w_rel_uart_0));  // Templated
m_qnsc_scrc_ctrl u_ctrl_uart_1  (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_uart_1),  // Templated
                                 .o_rst_n_sync          (o_rst_n_uart_1), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_uart_1),  // Templated
                                 .i_rst_n_in            (w_rel_uart_1));  // Templated
m_qnsc_scrc_ctrl u_ctrl_spi     (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_spi),     // Templated
                                 .o_rst_n_sync          (o_rst_n_spi),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_spi),     // Templated
                                 .i_rst_n_in            (w_rel_spi));     // Templated
m_qnsc_scrc_ctrl u_ctrl_i2c     (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_i2c),     // Templated
                                 .o_rst_n_sync          (o_rst_n_i2c),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_i2c),     // Templated
                                 .i_rst_n_in            (w_rel_i2c));     // Templated
m_qnsc_scrc_ctrl u_ctrl_gpio_0  (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_gpio_0),  // Templated
                                 .o_rst_n_sync          (o_rst_n_gpio_0), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_gpio_0),  // Templated
                                 .i_rst_n_in            (w_rel_gpio_0));  // Templated
m_qnsc_scrc_ctrl u_ctrl_dma     (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_dma),     // Templated
                                 .o_rst_n_sync          (o_rst_n_dma),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_dma),     // Templated
                                 .i_rst_n_in            (w_rel_dma));     // Templated
m_qnsc_scrc_ctrl u_ctrl_pwm     (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_pwm),     // Templated
                                 .o_rst_n_sync          (o_rst_n_pwm),   // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_pwm),     // Templated
                                 .i_rst_n_in            (w_rel_pwm));     // Templated
m_qnsc_scrc_ctrl u_ctrl_gpio_1  (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_gpio_1),  // Templated
                                 .o_rst_n_sync          (o_rst_n_gpio_1), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_gpio_1),  // Templated
                                 .i_rst_n_in            (w_rel_gpio_1));  // Templated
m_qnsc_scrc_ctrl u_ctrl_gpio_2  (/*AUTOINST*/
                                 // Outputs
                                 .o_clk_gated           (o_clk_gpio_2),  // Templated
                                 .o_rst_n_sync          (o_rst_n_gpio_2), // Templated
                                 // Inputs
                                 .i_clk_root            (w_clk_root),    // Templated
                                 .i_icg_en              (w_icg_gpio_2),  // Templated
                                 .i_rst_n_in            (w_rel_gpio_2));  // Templated

endmodule
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t
// indent-tabs-mode: nil
// eval: (setq large-file-warning-threshold nil)
// End:
