`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: m_vlsi_arbiter_i2c
//Function: APB Arbiter
//Author: link
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module m_vlsi_arbiter_i2c (
  // ============================================================================
  // Slave Interface: I2C
  // ============================================================================
  input  logic          i_clk,
  input  logic          i_rstn,
  output logic [3:0]   o_paddr,
  output logic          o_protect_en,
  output logic          o_slverr_en,
  output logic [2:0]    o_pprot,
  output logic [31:0]   o_pwdata,
  output logic          o_pwrite,
  output logic          o_penable,
  output logic          o_psel,
  output logic [3:0]    o_pstrb,
  input  logic          i_pslverr,
  input  logic          i_pready,
  input  logic [31:0]   i_prdata,
  // ============================================================================
  // Master Interface 1: CPU0
  // ============================================================================
  input  logic [3:0]   i_paddr_cpu0,
  input  logic          i_protect_en_cpu0,
  input  logic          i_slverr_en_cpu0,
  input  logic [2:0]    i_pprot_cpu0,
  input  logic [31:0]   i_pwdata_cpu0,
  input  logic          i_pwrite_cpu0,
  input  logic          i_penable_cpu0,
  input  logic          i_psel_cpu0,
  input  logic [3:0]    i_pstrb_cpu0,
  output logic          o_pslverr_cpu0,
  output logic          o_pready_cpu0,
  output logic [31:0]   o_prdata_cpu0,
  // ============================================================================
  // Master Interface 2: CPU1
  // ============================================================================
  input  logic [3:0]   i_paddr_cpu1,
  input  logic          i_protect_en_cpu1,
  input  logic          i_slverr_en_cpu1,
  input  logic [2:0]    i_pprot_cpu1,
  input  logic [31:0]   i_pwdata_cpu1,
  input  logic          i_pwrite_cpu1,
  input  logic          i_penable_cpu1,
  input  logic          i_psel_cpu1,
  input  logic [3:0]    i_pstrb_cpu1,
  output logic          o_pslverr_cpu1,
  output logic          o_pready_cpu1,
  output logic [31:0]   o_prdata_cpu1,
  // ============================================================================
  // Master Interface 3: GPU
  // ============================================================================
  input  logic [3:0]   i_paddr_gpu,
  input  logic          i_protect_en_gpu,
  input  logic          i_slverr_en_gpu,
  input  logic [2:0]    i_pprot_gpu,
  input  logic [31:0]   i_pwdata_gpu,
  input  logic          i_pwrite_gpu,
  input  logic          i_penable_gpu,
  input  logic          i_psel_gpu,
  input  logic [3:0]    i_pstrb_gpu,
  output logic          o_pslverr_gpu,
  output logic          o_pready_gpu,
  output logic [31:0]   o_prdata_gpu,
  // ============================================================================
  // Master Interface 4: NPU
  // ============================================================================
  input  logic [3:0]   i_paddr_npu,
  input  logic          i_protect_en_npu,
  input  logic          i_slverr_en_npu,
  input  logic [2:0]    i_pprot_npu,
  input  logic [31:0]   i_pwdata_npu,
  input  logic          i_pwrite_npu,
  input  logic          i_penable_npu,
  input  logic          i_psel_npu,
  input  logic [3:0]    i_pstrb_npu,
  output logic          o_pslverr_npu,
  output logic          o_pready_npu,
  output logic [31:0]   o_prdata_npu,
  // ============================================================================
  // Master Interface 5: TPU
  // ============================================================================
  input  logic [3:0]   i_paddr_tpu,
  input  logic          i_protect_en_tpu,
  input  logic          i_slverr_en_tpu,
  input  logic [2:0]    i_pprot_tpu,
  input  logic [31:0]   i_pwdata_tpu,
  input  logic          i_pwrite_tpu,
  input  logic          i_penable_tpu,
  input  logic          i_psel_tpu,
  input  logic [3:0]    i_pstrb_tpu,
  output logic          o_pslverr_tpu,
  output logic          o_pready_tpu,
  output logic [31:0]   o_prdata_tpu,
  // ============================================================================
  // Master Interface 6: PPU
  // ============================================================================
  input  logic [3:0]   i_paddr_ppu,
  input  logic          i_protect_en_ppu,
  input  logic          i_slverr_en_ppu,
  input  logic [2:0]    i_pprot_ppu,
  input  logic [31:0]   i_pwdata_ppu,
  input  logic          i_pwrite_ppu,
  input  logic          i_penable_ppu,
  input  logic          i_psel_ppu,
  input  logic [3:0]    i_pstrb_ppu,
  output logic          o_pslverr_ppu,
  output logic          o_pready_ppu,
  output logic [31:0]   o_prdata_ppu
);
  logic [5:0] psel_comb;
  logic [5:0] grant_comb;

  // ============================================================================
  // Master Select Logic
  // ============================================================================
  assign psel_comb = {i_psel_ppu, i_psel_tpu, i_psel_npu, i_psel_gpu, i_psel_cpu1, i_psel_cpu0};

  logic [5:0] grant_prev;
  logic          grant_handover;
  logic          sel_penable;

  always_ff @(posedge i_clk or negedge i_rstn) begin
    if (!i_rstn)
      grant_prev <= '0;
    else
      grant_prev <= grant_comb;
  end

  // Force SETUP (PENABLE=0) for one cycle when grant owner changes.
  assign grant_handover = (grant_comb != grant_prev) && (|grant_comb);



  ArbBalanceRR #(
    .REQ_NUM (6)
  ) u_arb (
  .clk (i_clk),
  .rst_n (i_rstn),
  .req (psel_comb),
  .grant (grant_comb)
  );

  // ============================================================================
  // Master-to-Slave Data Routing
  // ============================================================================
  always_comb begin
    casez (grant_comb)
      6'b?????1: begin  // CPU0
        o_paddr         = i_paddr_cpu0;
        o_protect_en    = i_protect_en_cpu0;
        o_slverr_en     = i_slverr_en_cpu0;
        o_pprot         = i_pprot_cpu0;
        o_pwdata        = i_pwdata_cpu0;
        o_pwrite        = i_pwrite_cpu0;
        sel_penable     = i_penable_cpu0;
        o_psel          = i_psel_cpu0;
        o_pstrb         = i_pstrb_cpu0;
      end

      6'b????10: begin  // CPU1
        o_paddr         = i_paddr_cpu1;
        o_protect_en    = i_protect_en_cpu1;
        o_slverr_en     = i_slverr_en_cpu1;
        o_pprot         = i_pprot_cpu1;
        o_pwdata        = i_pwdata_cpu1;
        o_pwrite        = i_pwrite_cpu1;
        sel_penable     = i_penable_cpu1;
        o_psel          = i_psel_cpu1;
        o_pstrb         = i_pstrb_cpu1;
      end

      6'b???100: begin  // GPU
        o_paddr         = i_paddr_gpu;
        o_protect_en    = i_protect_en_gpu;
        o_slverr_en     = i_slverr_en_gpu;
        o_pprot         = i_pprot_gpu;
        o_pwdata        = i_pwdata_gpu;
        o_pwrite        = i_pwrite_gpu;
        sel_penable     = i_penable_gpu;
        o_psel          = i_psel_gpu;
        o_pstrb         = i_pstrb_gpu;
      end

      6'b??1000: begin  // NPU
        o_paddr         = i_paddr_npu;
        o_protect_en    = i_protect_en_npu;
        o_slverr_en     = i_slverr_en_npu;
        o_pprot         = i_pprot_npu;
        o_pwdata        = i_pwdata_npu;
        o_pwrite        = i_pwrite_npu;
        sel_penable     = i_penable_npu;
        o_psel          = i_psel_npu;
        o_pstrb         = i_pstrb_npu;
      end

      6'b?10000: begin  // TPU
        o_paddr         = i_paddr_tpu;
        o_protect_en    = i_protect_en_tpu;
        o_slverr_en     = i_slverr_en_tpu;
        o_pprot         = i_pprot_tpu;
        o_pwdata        = i_pwdata_tpu;
        o_pwrite        = i_pwrite_tpu;
        sel_penable     = i_penable_tpu;
        o_psel          = i_psel_tpu;
        o_pstrb         = i_pstrb_tpu;
      end

      6'b100000: begin  // PPU
        o_paddr         = i_paddr_ppu;
        o_protect_en    = i_protect_en_ppu;
        o_slverr_en     = i_slverr_en_ppu;
        o_pprot         = i_pprot_ppu;
        o_pwdata        = i_pwdata_ppu;
        o_pwrite        = i_pwrite_ppu;
        sel_penable     = i_penable_ppu;
        o_psel          = i_psel_ppu;
        o_pstrb         = i_pstrb_ppu;
      end

      default: begin
        o_paddr         = '0;
        o_protect_en    = '0;
        o_slverr_en     = '0;
        o_pprot         = '0;
        o_pwdata        = '0;
        o_pwrite        = '0;
        sel_penable     = '0;
        o_psel          = '0;
        o_pstrb         = '0;
      end
    endcase
  end

  assign o_penable = o_psel ? (sel_penable & ~grant_handover) : 1'b0;


  // ============================================================================
  // Slave-to-Master Data Routing
  // ============================================================================
  assign o_pslverr_cpu0 = grant_comb[0] ? i_pslverr : '0;
  assign o_pready_cpu0  = grant_comb[0] ? i_pready  : '0;
  assign o_prdata_cpu0  = grant_comb[0] ? i_prdata  : '0;
  assign o_pslverr_cpu1 = grant_comb[1] ? i_pslverr : '0;
  assign o_pready_cpu1  = grant_comb[1] ? i_pready  : '0;
  assign o_prdata_cpu1  = grant_comb[1] ? i_prdata  : '0;
  assign o_pslverr_gpu  = grant_comb[2] ? i_pslverr : '0;
  assign o_pready_gpu   = grant_comb[2] ? i_pready  : '0;
  assign o_prdata_gpu   = grant_comb[2] ? i_prdata  : '0;
  assign o_pslverr_npu  = grant_comb[3] ? i_pslverr : '0;
  assign o_pready_npu   = grant_comb[3] ? i_pready  : '0;
  assign o_prdata_npu   = grant_comb[3] ? i_prdata  : '0;
  assign o_pslverr_tpu  = grant_comb[4] ? i_pslverr : '0;
  assign o_pready_tpu   = grant_comb[4] ? i_pready  : '0;
  assign o_prdata_tpu   = grant_comb[4] ? i_prdata  : '0;
  assign o_pslverr_ppu  = grant_comb[5] ? i_pslverr : '0;
  assign o_pready_ppu   = grant_comb[5] ? i_pready  : '0;
  assign o_prdata_ppu   = grant_comb[5] ? i_prdata  : '0;

endmodule
