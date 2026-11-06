`timescale 1ns/1ps
//--------------------------------------
//Project: APB BUS Generator
//Module: //MODULE_NAME
//Function: APB Arbiter
//Author: //AUTHOR
//Script Author: Trthinh (Ethan), Thang Luong (superzeldalink)
//Page: VLSI Technology
//--------------------------------------

module //MODULE_NAME (
//PORT
);
  logic [//MASTER_NUM-1:0] psel_comb;
  logic [//MASTER_NUM-1:0] grant_comb;

//PSEL

  ArbBalanceRR #(
    .REQ_NUM (//MASTER_NUM)
  ) u_arb (
  .clk (i_clk),
  .rst_n (i_rstn),
  .req (psel_comb),
  .grant (grant_comb)
  );

//MST2SLV_LOGIC
//SLV2MST_LOGIC
endmodule
