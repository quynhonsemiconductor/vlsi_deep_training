`default_nettype none
`timescale 1ns/1ps
//==============================================================================
// Model   : tb_apb_slave
// Purpose : an APB4 slave standing for P_BUS behind S_BUS's one APB port: a 256-word memory,
//           P_WAIT wait states, and PSLVERR for the word at P_ERR_OFFSET.
// Checks  : proto_err is set when PENABLE rises without a setup cycle, or when PSEL, PWRITE,
//           PADDR or PWDATA change during the access phase.
// Counters: n_access and the last access, for the tests to compare.
//==============================================================================
module tb_apb_slave #(
  parameter int unsigned P_WAIT       = 0,
  parameter logic [17:0] P_ERR_OFFSET = 18'h00100
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [17:0] paddr,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] pwdata,
  input  logic [3:0]  pstrb,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  logic [31:0] mem [0:255];    // filled with 32'hD000_0000 | index by the reset

  int unsigned n_access;
  logic [17:0] last_paddr;
  logic [31:0] last_pwdata;
  logic [3:0]  last_pstrb;
  logic        last_pwrite;
  logic        proto_err;

  int unsigned wait_cnt;
  logic        r_psel_q, r_penable_q, r_pwrite_q;
  logic [17:0] r_paddr_q;
  logic [31:0] r_pwdata_q;

  assign pready  = psel && penable && (wait_cnt >= P_WAIT);
  assign pslverr = pready && (paddr == P_ERR_OFFSET);
  assign prdata  = (pready && !pwrite) ? mem[paddr[9:2]] : 32'h0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wait_cnt <= 0; n_access <= 0; proto_err <= 1'b0;
      for (int i = 0; i < 256; i++) mem[i] <= 32'hD000_0000 | 32'(i);
      last_paddr <= '0; last_pwdata <= '0; last_pstrb <= '0; last_pwrite <= 1'b0;
      r_psel_q <= 1'b0; r_penable_q <= 1'b0; r_pwrite_q <= 1'b0; r_paddr_q <= '0; r_pwdata_q <= '0;
    end else begin
      r_psel_q <= psel; r_penable_q <= penable; r_pwrite_q <= pwrite;
      r_paddr_q <= paddr; r_pwdata_q <= pwdata;
      // PENABLE may only rise one cycle after PSEL (a setup cycle)
      if (penable && !r_penable_q && !(r_psel_q && !r_penable_q)) proto_err <= 1'b1;
      if (penable && !psel) proto_err <= 1'b1;
      // the request does not change during the access phase
      if (r_penable_q && penable &&
          (r_paddr_q != paddr || r_pwrite_q != pwrite || (pwrite && r_pwdata_q != pwdata)))
        proto_err <= 1'b1;
      if (psel && penable) begin
        if (pready) begin
          wait_cnt <= 0;
          n_access <= n_access + 1;
          last_paddr <= paddr; last_pwdata <= pwdata; last_pstrb <= pstrb; last_pwrite <= pwrite;
          if (pwrite)
            for (int b = 0; b < 4; b++)
              if (pstrb[b]) mem[paddr[9:2]][8*b +: 8] <= pwdata[8*b +: 8];
        end else begin
          wait_cnt <= wait_cnt + 1;
        end
      end else begin
        wait_cnt <= 0;
      end
    end
  end

endmodule : tb_apb_slave
`default_nettype wire
