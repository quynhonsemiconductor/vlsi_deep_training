`include "i2c_master_defines.sv"

`define REG_CLK_PRESCALER 3'b000 //BASEADDR+0x00
`define REG_CTRL          3'b001 //BASEADDR+0x04
`define REG_RX            3'b010 //BASEADDR+0x08
`define REG_STATUS        3'b011 //BASEADDR+0x0C
`define REG_TX            3'b100 //BASEADDR+0x10
`define REG_CMD           3'b101 //BASEADDR+0x14
// Combined TX+command and RX+command registers for the QSOC peripheral-
// triggered DMA channel:
// a single fixed-address write/read lets a DMA channel stream consecutive
// bytes without software re-issuing REG_CMD for every byte.
`define REG_TXCMD         3'b110 //BASEADDR+0x18
`define REG_RXCMD         3'b111 //BASEADDR+0x1C

module apb_i2c
#(
    parameter APB_ADDR_WIDTH = 12  //APB slaves are 4KB by default
)
(
    input  logic                      HCLK,
    input  logic                      HRESETn,
    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic               [31:0] PWDATA,
    input  logic                      PWRITE,
    input  logic                      PSEL,
    input  logic                      PENABLE,
    output logic               [31:0] PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR,
    output logic                      interrupt_o,
    // DMA request lines for the QSOC peripheral-triggered DMA channel.
    // dma_tx_req_o: core idle and ready to accept the next REG_TXCMD write.
    // dma_rx_req_o: a byte read via REG_RXCMD is waiting to be collected.
    output logic                      dma_tx_req_o,
    output logic                      dma_rx_req_o,
    // Asserted by the DMA channel while it issues the read that will consume
    // the LAST byte of an RX burst: REG_RXCMD then auto-issues NACK+STOP
    // instead of ACK+continue for the following byte.
    input  logic                      dma_last_i,
    input  logic                      scl_pad_i,
    output logic                      scl_pad_o,
    output logic                      scl_padoen_o,
    input  logic                      sda_pad_i,
    output logic                      sda_pad_o,
    output logic                      sda_padoen_o
);

    //
    // variable declarations
    //

    logic  [3:0] s_apb_addr;

    // registers
    reg  [15:0] r_pre; // clock prescale register
    reg  [ 7:0] r_ctrl;  // control register
    reg  [ 7:0] r_tx;  // transmit register
    wire [ 7:0] s_rx;  // receive register
    reg  [ 7:0] r_cmd;   // command register
    wire [ 7:0] s_status;   // status register

    // done signal: command completed, clear command register
    wire s_done;

    // core enable signal
    wire s_core_en;
    wire s_ien;

    // status register signals
    wire s_irxack;
    reg  rxack;       // received aknowledge from slave
    reg  tip;         // transfer in progress
    reg  irq_flag;    // interrupt pending flag
    wire i2c_busy;    // bus busy (start signal detected)
    wire i2c_al;      // i2c bus arbitration lost
    reg  al;          // status register arbitration lost bit
    // decode command register
    wire sta  = r_cmd[7];
    wire sto  = r_cmd[6];
    wire rd   = r_cmd[5];
    wire wr   = r_cmd[4];
    wire ack  = r_cmd[3];
    wire iack = r_cmd[0];

    //
    // module body
    //

    assign s_apb_addr = PADDR[5:2];

    always_ff @ (posedge HCLK, negedge HRESETn)
    begin
        if(~HRESETn)
        begin
            r_pre  <= 'h0;
            r_ctrl <= 'h0;
            r_tx   <= 'h0;
            r_cmd  <= 'h0;
        end
        else if (PSEL && PENABLE && PWRITE)
             begin
                if (s_done | i2c_al)
                      r_cmd[7:4] <= 4'h0;          // clear command bits when done
                                                   // or when aribitration lost
                r_cmd[2:1] <= 2'b0;                 // reserved bits
                r_cmd[0]   <= 1'b0;                 // clear IRQ_ACK bit
                case (s_apb_addr)
                    `REG_CLK_PRESCALER:
                        r_pre <= PWDATA[15:0];
                    `REG_CTRL:
                        r_ctrl <= PWDATA[7:0];
                    `REG_TX:
                        r_tx <= PWDATA[7:0];
                    `REG_CMD:
                    begin
                        if(s_core_en)
                            r_cmd <= PWDATA[7:0];
                    end
                    `REG_TXCMD:
                    begin
                        // DMA-friendly TX path: one write both loads the data
                        // byte and auto-issues WR (+START/STOP taken from the
                        // source word, so software pre-marks the first/last
                        // byte of the burst in the DMA source buffer).
                        r_tx <= PWDATA[7:0];
                        if (s_core_en)
                            // r_cmd = {sta, sto, rd, wr, ack, rsvd[1:0], iack}
                            r_cmd <= {PWDATA[8], PWDATA[9], 1'b0, 1'b1, 1'b0, 2'b0, 1'b0};
                    end
                endcase
            end
            else if (PSEL && PENABLE && ~PWRITE && s_core_en && (s_apb_addr == `REG_RXCMD))
            begin
                // DMA-friendly RX path: reading REG_RXCMD both returns the
                // previous byte (see PRDATA mux below) and auto-issues the
                // next RD command. dma_last_i (driven by the DMA channel on
                // the read that will consume the final byte) selects
                // NACK+STOP instead of ACK+continue.
                if (s_done | i2c_al)
                    r_cmd[7:4] <= 4'h0;
                // r_cmd = {sta, sto, rd, wr, ack, rsvd[1:0], iack}
                // sto=ack=dma_last_i: on the last byte, NACK the slave and
                // issue STOP in the same command; otherwise ACK and continue.
                r_cmd <= {1'b0, dma_last_i, 1'b1, 1'b0, dma_last_i, 2'b0, 1'b0};
            end
            else
            begin
                if (s_done | i2c_al)
                    r_cmd[7:4] <= 4'h0;           // clear command bits when done
                                                  // or when aribitration lost
                r_cmd[2:1] <= 2'b0;               // reserved bits
                r_cmd[0]   <= 1'b0;               // clear IRQ_ACK bit
            end
    end //always

    // ------------------------------------------------------------------
    // DMA request generation (QSOC peripheral-triggered DMA channel)
    // ------------------------------------------------------------------
    reg rx_rdy_q;
    always_ff @ (posedge HCLK, negedge HRESETn)
    begin
        if (~HRESETn)
            rx_rdy_q <= 1'b0;
        else if (s_done && rd)
            rx_rdy_q <= 1'b1;
        else if (PSEL && PENABLE && ~PWRITE && s_core_en && (s_apb_addr == `REG_RXCMD))
            rx_rdy_q <= 1'b0;
    end

    assign dma_tx_req_o = s_core_en & ~tip;
    assign dma_rx_req_o = rx_rdy_q;

    always_comb
    begin
        case (s_apb_addr)
            `REG_CLK_PRESCALER:
                PRDATA = {16'h0,r_pre};
            `REG_CTRL:
                PRDATA = {24'h0,r_ctrl};
            `REG_RX:
                PRDATA = {24'h0,s_rx};
            `REG_STATUS: 
                PRDATA = {24'h0,s_status};
            `REG_TX:    
                PRDATA = {24'h0,r_tx};
            `REG_CMD:
                PRDATA = {24'h0,r_cmd};
            `REG_RXCMD:
                PRDATA = {24'h0,s_rx}; // read here also auto-issues the next RD (see always_ff above)
            default:
                PRDATA = 'h0;
        endcase
    end


    // decode control register
    assign s_core_en = r_ctrl[7];
    assign s_ien     = r_ctrl[6];

    // hookup byte controller block
    i2c_master_byte_ctrl byte_controller 
    (
            .clk      ( HCLK         ),
            .nReset   ( HRESETn      ),
            .ena      ( s_core_en    ),
            .clk_cnt  ( r_pre        ),
            .start    ( sta          ),
            .stop     ( sto          ),
            .read     ( rd           ),
            .write    ( wr           ),
            .ack_in   ( ack          ),
            .din      ( r_tx         ),
            .cmd_ack  ( s_done       ),
            .ack_out  ( s_irxack     ),
            .dout     ( s_rx         ),
            .i2c_busy ( i2c_busy     ),
            .i2c_al   ( i2c_al       ),
            .scl_i    ( scl_pad_i    ),
            .scl_o    ( scl_pad_o    ),
            .scl_oen  ( scl_padoen_o ),
            .sda_i    ( sda_pad_i    ),
            .sda_o    ( sda_pad_o    ),
            .sda_oen  ( sda_padoen_o )
    );

    // status register block + interrupt request signal
    always_ff @(posedge HCLK, negedge HRESETn)
    begin
        if (!HRESETn)
        begin
            al       <= 1'b0;
            rxack    <= 1'b0;
            tip      <= 1'b0;
            irq_flag <= 1'b0;
        end
        else
        begin
            al       <= i2c_al | (al & ~sta);
            rxack    <= s_irxack;
            tip      <= (rd | wr);
            irq_flag <= (s_done | i2c_al | irq_flag) & ~iack; // interrupt request flag is always generated
        end
    end

    // generate interrupt request signals
    always_ff @(posedge HCLK, negedge HRESETn)
    begin
        if (!HRESETn)
            interrupt_o <= 1'b0;
        else
            interrupt_o <= irq_flag && s_ien; // interrupt signal is only generated when IEN (interrupt enable bit is set)
    end
 
    // assign status register bits
    assign s_status[7]   = rxack;
    assign s_status[6]   = i2c_busy;
    assign s_status[5]   = al;
    assign s_status[4:2] = 3'h0; // reserved
    assign s_status[1]   = tip;
    assign s_status[0]   = irq_flag;

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

endmodule
