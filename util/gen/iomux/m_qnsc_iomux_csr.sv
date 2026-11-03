`timescale 1ns/1ps
//--------------------------------------------------------------------
// Project: APB-CSR-Generator
// Generator: apb-csr-generator
// Date and time: fixed by util/gen/iomux/gen.sh
// Module: m_qnsc_iomux_csr
// Function: Control & Status register via APB interface
// Page: VLSI Technology
//--------------------------------------------------------------------
module m_qnsc_iomux_csr # (
  localparam PARA_PADSEL_0_OFFSET = 16'h0000,
  localparam PARA_PADSEL_1_OFFSET = 16'h0004

)(
  input i_bus_clk,
  input i_bus_rstn,
  input [15:0] i_paddr,
  input i_protect_en,
  input i_slverr_en,
  input [2:0] i_pprot,
  input [31:0] i_pwdata,
  input i_pwrite,
  input i_penable,
  input i_psel,
  input [3:0] i_pstrb,
  output o_pslverr,
  output o_pready,
  output [31:0] o_prdata,
  output [31:0] o_padsel_0_sel,
  output [23:0] o_padsel_1_sel
);
  //Logic signal declaration
  logic apb_setup;
  logic apb_protect;
  logic apb_slverr;
  logic apb_complete;
  logic apb_write;
  logic apb_read;
  logic [15:0] reg_address;
  logic [31:0] reg_pwdata;
  logic reg_slverr;
  logic apb_read_en;
  logic apb_write_en;
  logic [31:0] nxt_prdata;
  logic reg_pready;
  logic [31:0] reg_prdata;
  logic reg_apb_read_capture;
  logic reg_apb_write_capture;
  logic we_padsel_0;
  logic [31:0] reg_padsel_0_sel;
  logic [31:0] nxt_padsel_0_sel;
  logic [31:0] padsel_0_value;
  logic we_padsel_1;
  logic [23:0] reg_padsel_1_sel;
  logic [23:0] nxt_padsel_1_sel;
  logic [31:0] padsel_1_value;
  //end of logic signal declaration

  //APB general access phase assignment - START
  assign apb_setup = i_psel & ~i_penable;
  assign apb_protect = i_protect_en ? ~i_pprot[1] : 1'b1;
  assign apb_slverr = i_slverr_en ? (~apb_protect      //error in protection
                      | (|i_paddr[1:0]) //error in address 
                      | (~&i_pstrb & i_pwrite)) : 1'b0;    //error in pstrb signal
  assign apb_complete = apb_setup & (~apb_slverr);
  assign apb_write = i_pwrite & apb_complete;
  assign apb_read = ~i_pwrite & apb_complete; 
  
  //APB capture FF phase
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //address capture FF
    if(!i_bus_rstn) 
      reg_address <= '0;
    else if (apb_complete)
      reg_address <= i_paddr;
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //write data capture FF
    if(!i_bus_rstn) 
      reg_pwdata <= '0;
    else if (apb_write)
      reg_pwdata <= i_pwdata;
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //slverr output FF
    if(!i_bus_rstn) 
      reg_slverr <= '0;
    else if (apb_setup & i_slverr_en)
      reg_slverr <= apb_slverr;
  end
  assign o_pslverr = reg_slverr;
  //--------------------------------------------------------------------
  assign we_padsel_0 = apb_write_en & (reg_address == PARA_PADSEL_0_OFFSET);
  assign we_padsel_1 = apb_write_en & (reg_address == PARA_PADSEL_1_OFFSET);


  //APB read/write register (appear when option Async is not selected) - START
  //--------------------------------------------------------------------
  //Reading phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_apb_read_capture <= '0;
    else
      reg_apb_read_capture <= apb_read;
  end
  assign apb_read_en = reg_apb_read_capture;

  //--------------------------------------------------------------------
  //Writing phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_apb_write_capture <= '0;
    else
      reg_apb_write_capture <= apb_write;
  end
  assign apb_write_en = reg_apb_write_capture;

  //--------------------------------------------------------------------
  //PREADY phase
  //--------------------------------------------------------------------
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_pready <= '0;
    else
      reg_pready <= apb_write_en // reading complete
                | apb_read_en // writing complete
                | (apb_slverr & apb_setup);//slverr assert
  end
  assign o_pready = reg_pready;
  
  //--------------------------------------------------------------------

  //Assignment for next value of padsel_0_sel rw
  assign nxt_padsel_0_sel = (we_padsel_0) ? reg_pwdata[31:0] : reg_padsel_0_sel;
  //FF for bit padsel_0_sel
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_padsel_0_sel <= 32'h0;
    else
      reg_padsel_0_sel <= nxt_padsel_0_sel;
  end 
  assign o_padsel_0_sel = reg_padsel_0_sel;

  //--------------------------------------------------------------------
  //Combine the value of padsel_0
  //--------------------------------------------------------------------
  always_comb begin
    padsel_0_value[31:0] = reg_padsel_0_sel;
  end  //Assignment for next value of padsel_1_sel rw
  assign nxt_padsel_1_sel = (we_padsel_1) ? reg_pwdata[23:0] : reg_padsel_1_sel;
  //FF for bit padsel_1_sel
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_padsel_1_sel <= 24'h0;
    else
      reg_padsel_1_sel <= nxt_padsel_1_sel;
  end 
  assign o_padsel_1_sel = reg_padsel_1_sel;

  //--------------------------------------------------------------------
  //Combine the value of padsel_1
  //--------------------------------------------------------------------
  always_comb begin
    padsel_1_value[31:24] = '0;
    padsel_1_value[23:0] = reg_padsel_1_sel;
  end
  //--------------------------------------------------------------------
  //O_PRDATA phase
  //--------------------------------------------------------------------
  always_comb begin
    case (reg_address)
      PARA_PADSEL_0_OFFSET: nxt_prdata = padsel_0_value;
      PARA_PADSEL_1_OFFSET: nxt_prdata = padsel_1_value;
      default nxt_prdata = '0;
    endcase
  end
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin
    if(!i_bus_rstn) 
      reg_prdata <= '0;
    else if (apb_read_en)
      reg_prdata <= nxt_prdata;
  end
  assign o_prdata = reg_prdata;

endmodule: m_qnsc_iomux_csr