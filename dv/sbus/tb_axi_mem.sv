`default_nettype none
`timescale 1ns/1ps
//==============================================================================
// Model   : tb_axi_mem
// Purpose : an AXI4 slave with a small memory, standing in for ROM, ISRAM or DSRAM on one
//           master port of S_BUS. It takes the same signals as those wrappers: a master-port
//           request struct (id, addr, len, burst, w data/strb/last) and answers OKAY. It has
//           no size, lock, cache, prot, qos, region, atop and user input, and no b_user or
//           r_user output: those are tied to 0 here, as TOP ties them.
// Counters: what the model saw, for the tests to compare (n_aw, n_ar, last_*), and w_err,
//           set when a write burst's WLAST does not come with the last beat.
// Timing  : P_DELAY cycles of waiting before AW/AR ready, before each R beat and before B,
//           so a test also covers a slow slave. P_PATTERN | word index is the initial data.
//==============================================================================
module tb_axi_mem #(
  parameter int unsigned P_DELAY   = 0,
  parameter logic [31:0] P_PATTERN = 32'h0
) (
  input  logic                      clk,
  input  logic                      rst_n,
  input  qnsc_sbus_pkg::mst_req_t   req,
  output qnsc_sbus_pkg::mst_resp_t  resp
);

  logic [31:0] mem [0:16383];   // 64 KiB, so ISRAM's debug window and ISRAM stay apart; filled by the reset of the write side

  // what the testbench reads back
  int unsigned n_aw, n_w, n_ar;
  logic [2:0]  aw_id_seen, ar_id_seen;
  logic [31:0] aw_addr_seen, ar_addr_seen;
  logic [7:0]  aw_len_seen, ar_len_seen;
  logic        w_err;

  // ---- write side ----------------------------------------------------------
  typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wst_t;
  wst_t        w_st;
  logic [2:0]  w_id;
  logic [31:0] w_addr;
  logic [7:0]  w_len;
  logic [8:0]  w_cnt;
  int unsigned w_wait;

  wire aw_hs = req.aw_valid && resp.aw_ready;
  wire w_hs  = req.w_valid  && resp.w_ready;
  wire b_hs  = resp.b_valid && req.b_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_st <= W_IDLE; w_id <= '0; w_addr <= '0; w_len <= '0; w_cnt <= '0; w_wait <= 0;
      n_aw <= 0; n_w <= 0; aw_id_seen <= '0; aw_addr_seen <= '0; aw_len_seen <= '0; w_err <= 1'b0;
      for (int i = 0; i < 16384; i++) mem[i] <= P_PATTERN | 32'(i);
    end else begin
      case (w_st)
        W_IDLE: begin
          if (aw_hs) begin
            w_st <= W_DATA; w_id <= req.aw.id; w_addr <= req.aw.addr; w_len <= req.aw.len;
            w_cnt <= '0; w_wait <= 0; n_aw <= n_aw + 1;
            aw_id_seen <= req.aw.id; aw_addr_seen <= req.aw.addr; aw_len_seen <= req.aw.len;
          end else if (req.aw_valid) begin
            w_wait <= w_wait + 1;
          end
        end
        W_DATA: begin
          if (w_hs) begin
            for (int b = 0; b < 4; b++)
              if (req.w.strb[b]) mem[w_addr[15:2]][8*b +: 8] <= req.w.data[8*b +: 8];
            w_addr <= w_addr + 32'd4;
            w_cnt  <= w_cnt + 9'd1;
            n_w    <= n_w + 1;
            if (req.w.last != (w_cnt == {1'b0, w_len})) w_err <= 1'b1;
            if (req.w.last) begin w_st <= W_RESP; w_wait <= 0; end
          end
        end
        W_RESP: begin
          if (b_hs) w_st <= W_IDLE;
          else if (w_wait < P_DELAY) w_wait <= w_wait + 1;
        end
        default: w_st <= W_IDLE;
      endcase
    end
  end

  // ---- read side -----------------------------------------------------------
  typedef enum logic [0:0] {R_IDLE, R_DATA} rst_t;
  rst_t        r_st;
  logic [2:0]  r_id;
  logic [31:0] r_addr;
  logic [7:0]  r_len;
  logic [8:0]  r_cnt;
  int unsigned r_wait;

  wire ar_hs = req.ar_valid && resp.ar_ready;
  wire r_hs  = resp.r_valid && req.r_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_st <= R_IDLE; r_id <= '0; r_addr <= '0; r_len <= '0; r_cnt <= '0; r_wait <= 0;
      n_ar <= 0; ar_id_seen <= '0; ar_addr_seen <= '0; ar_len_seen <= '0;
    end else begin
      case (r_st)
        R_IDLE: begin
          if (ar_hs) begin
            r_st <= R_DATA; r_id <= req.ar.id; r_addr <= req.ar.addr; r_len <= req.ar.len;
            r_cnt <= '0; r_wait <= 0; n_ar <= n_ar + 1;
            ar_id_seen <= req.ar.id; ar_addr_seen <= req.ar.addr; ar_len_seen <= req.ar.len;
          end else if (req.ar_valid) begin
            r_wait <= r_wait + 1;
          end
        end
        R_DATA: begin
          if (r_hs) begin
            r_addr <= r_addr + 32'd4;
            r_cnt  <= r_cnt + 9'd1;
            r_wait <= 0;
            if (r_cnt == {1'b0, r_len}) r_st <= R_IDLE;
          end else if (r_wait < P_DELAY) begin
            r_wait <= r_wait + 1;
          end
        end
        default: r_st <= R_IDLE;
      endcase
    end
  end

  // ---- the response struct -------------------------------------------------
  always_comb begin
    resp = '0;
    resp.aw_ready = (w_st == W_IDLE) && (w_wait >= P_DELAY);
    resp.w_ready  = (w_st == W_DATA);
    resp.b.id     = w_id;
    resp.b.resp   = axi_pkg::RESP_OKAY;
    resp.b_valid  = (w_st == W_RESP) && (w_wait >= P_DELAY);
    resp.ar_ready = (r_st == R_IDLE) && (r_wait >= P_DELAY);
    resp.r.id     = r_id;
    resp.r.data   = mem[r_addr[15:2]];
    resp.r.resp   = axi_pkg::RESP_OKAY;
    resp.r.last   = (r_cnt == {1'b0, r_len});
    resp.r_valid  = (r_st == R_DATA) && (r_wait >= P_DELAY);
    // no b_user and no r_user on the ROM and RAM wrappers: tied to 0
    resp.b.user   = '0;
    resp.r.user   = '0;
  end

endmodule : tb_axi_mem
`default_nettype wire
