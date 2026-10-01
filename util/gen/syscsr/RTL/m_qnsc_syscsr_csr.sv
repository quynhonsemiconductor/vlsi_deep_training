`timescale 1ns/1ps
//--------------------------------------------------------------------
// Project: APB-CSR-Generator
// Generator: benn2
// Date and time: 2026-09-29 10:00:47.439263
// Module: m_qnsc_syscsr_csr
// Function: Control & Status register via APB interface
// Page: VLSI Technology
//--------------------------------------------------------------------
module m_qnsc_syscsr_csr # (
  localparam PARA_RESETCAUSE_OFFSET = 16'h0000,
  localparam PARA_DOMAINRSTSTATUS_OFFSET = 16'h0004,
  localparam PARA_CHIPIDREV_OFFSET = 16'h0008

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
  output o_resetcause_cause_por,
  input i_hw_wdata_resetcause_cause_por,
  input i_hw_we_resetcause_cause_por,
  output o_resetcause_cause_wdt,
  input i_hw_wdata_resetcause_cause_wdt,
  input i_hw_we_resetcause_cause_wdt,
  output o_resetcause_cause_soft,
  input i_hw_wdata_resetcause_cause_soft,
  input i_hw_we_resetcause_cause_soft,
  input i_domainrststatus_stat_sbus,
  input i_domainrststatus_stat_pbus,
  input i_domainrststatus_stat_wdt,
  input i_domainrststatus_stat_timer_0,
  input i_domainrststatus_stat_timer_1,
  input i_domainrststatus_stat_uart_0,
  input i_domainrststatus_stat_uart_1,
  input i_domainrststatus_stat_spi,
  input i_domainrststatus_stat_i2c,
  input i_domainrststatus_stat_gpio_0,
  input i_domainrststatus_stat_dma,
  input i_domainrststatus_stat_rom,
  input i_domainrststatus_stat_ram,
  input i_domainrststatus_stat_sysdbg,
  input i_domainrststatus_stat_pwm,
  input i_domainrststatus_stat_gpio_1,
  input i_domainrststatus_stat_gpio_2,
  input i_domainrststatus_stat_cpu,
  input [31:0] i_chipidrev_chip_id_rev
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
  logic we_resetcause;
  logic reg_resetcause_cause_por;
  logic nxt_resetcause_cause_por;
  logic reg_resetcause_cause_wdt;
  logic nxt_resetcause_cause_wdt;
  logic reg_resetcause_cause_soft;
  logic nxt_resetcause_cause_soft;
  logic [31:0] resetcause_value;
  logic we_domainrststatus;
  logic [31:0] domainrststatus_value;
  logic [31:0] chipidrev_value;
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
  assign we_resetcause = apb_write_en & (reg_address == PARA_RESETCAUSE_OFFSET);
  assign we_domainrststatus = apb_write_en & (reg_address == PARA_DOMAINRSTSTATUS_OFFSET);


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

  //Assignment for next value of resetcause_cause_por w1c
  assign nxt_resetcause_cause_por = (we_resetcause) ? (~reg_pwdata[0] & reg_resetcause_cause_por)
                                  : (i_hw_we_resetcause_cause_por) ? i_hw_wdata_resetcause_cause_por
                                  : reg_resetcause_cause_por;
  //FF for bit resetcause_cause_por
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_resetcause_cause_por <= 1'h1;
    else
      reg_resetcause_cause_por <= nxt_resetcause_cause_por;
  end 
  assign o_resetcause_cause_por = reg_resetcause_cause_por;
  //Assignment for next value of resetcause_cause_wdt w1c
  assign nxt_resetcause_cause_wdt = (we_resetcause) ? (~reg_pwdata[1] & reg_resetcause_cause_wdt)
                                  : (i_hw_we_resetcause_cause_wdt) ? i_hw_wdata_resetcause_cause_wdt
                                  : reg_resetcause_cause_wdt;
  //FF for bit resetcause_cause_wdt
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_resetcause_cause_wdt <= 1'h0;
    else
      reg_resetcause_cause_wdt <= nxt_resetcause_cause_wdt;
  end 
  assign o_resetcause_cause_wdt = reg_resetcause_cause_wdt;
  //Assignment for next value of resetcause_cause_soft w1c
  assign nxt_resetcause_cause_soft = (we_resetcause) ? (~reg_pwdata[2] & reg_resetcause_cause_soft)
                                   : (i_hw_we_resetcause_cause_soft) ? i_hw_wdata_resetcause_cause_soft
                                   : reg_resetcause_cause_soft;
  //FF for bit resetcause_cause_soft
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_resetcause_cause_soft <= 1'h0;
    else
      reg_resetcause_cause_soft <= nxt_resetcause_cause_soft;
  end 
  assign o_resetcause_cause_soft = reg_resetcause_cause_soft;

  //--------------------------------------------------------------------
  //Combine the value of resetcause
  //--------------------------------------------------------------------
  always_comb begin
    resetcause_value[0] = reg_resetcause_cause_por;
    resetcause_value[1] = reg_resetcause_cause_wdt;
    resetcause_value[2] = reg_resetcause_cause_soft;
    resetcause_value[31:3] = '0;
  end
  //--------------------------------------------------------------------
  //Combine the value of domainrststatus
  //--------------------------------------------------------------------
  always_comb begin
    domainrststatus_value[0] = i_domainrststatus_stat_sbus;
    domainrststatus_value[1] = i_domainrststatus_stat_pbus;
    domainrststatus_value[2] = i_domainrststatus_stat_wdt;
    domainrststatus_value[3] = i_domainrststatus_stat_timer_0;
    domainrststatus_value[4] = i_domainrststatus_stat_timer_1;
    domainrststatus_value[5] = i_domainrststatus_stat_uart_0;
    domainrststatus_value[6] = i_domainrststatus_stat_uart_1;
    domainrststatus_value[7] = i_domainrststatus_stat_spi;
    domainrststatus_value[8] = i_domainrststatus_stat_i2c;
    domainrststatus_value[9] = i_domainrststatus_stat_gpio_0;
    domainrststatus_value[10] = i_domainrststatus_stat_dma;
    domainrststatus_value[11] = i_domainrststatus_stat_rom;
    domainrststatus_value[12] = i_domainrststatus_stat_ram;
    domainrststatus_value[13] = '0;
    domainrststatus_value[14] = i_domainrststatus_stat_sysdbg;
    domainrststatus_value[15] = i_domainrststatus_stat_pwm;
    domainrststatus_value[16] = i_domainrststatus_stat_gpio_1;
    domainrststatus_value[17] = i_domainrststatus_stat_gpio_2;
    domainrststatus_value[30:18] = '0;
    domainrststatus_value[31] = i_domainrststatus_stat_cpu;
  end
  //--------------------------------------------------------------------
  //Combine the value of chipidrev
  //--------------------------------------------------------------------
  always_comb begin
    chipidrev_value[31:0] = i_chipidrev_chip_id_rev;
  end
  //--------------------------------------------------------------------
  //O_PRDATA phase
  //--------------------------------------------------------------------
  always_comb begin
    case (reg_address)
      PARA_RESETCAUSE_OFFSET: nxt_prdata = resetcause_value;
      PARA_DOMAINRSTSTATUS_OFFSET: nxt_prdata = domainrststatus_value;
      PARA_CHIPIDREV_OFFSET: nxt_prdata = chipidrev_value;
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

endmodule: m_qnsc_syscsr_csr