`timescale 1ns/1ps
//--------------------------------------------------------------------
// Project: APB-CSR-Generator
// Generator: apb-csr-generator
// Date and time: fixed by util/gen/scrc_csr/gen.sh
// Module: m_qnsc_scrc_csr
// Function: Control & Status register via APB interface
// Page: VLSI Technology
//--------------------------------------------------------------------
module m_qnsc_scrc_csr # (
  localparam PARA_SWRST_OFFSET = 16'h0000,
  localparam PARA_CLKEN_OFFSET = 16'h0004,
  localparam PARA_ICGEN_OFFSET = 16'h000C,
  localparam PARA_RSTREL_OFFSET = 16'h0010,
  localparam PARA_APBBLK_OFFSET = 16'h0014,
  localparam PARA_APBBUSY_OFFSET = 16'h0018

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
  output o_swrst_sw_rst,
  output o_clken_en_timer_0,
  output o_clken_en_timer_1,
  output o_clken_en_uart_0,
  output o_clken_en_uart_1,
  output o_clken_en_spi,
  output o_clken_en_i2c,
  output o_clken_en_gpio_0,
  output o_clken_en_dma,
  output o_clken_en_pwm,
  output o_clken_en_gpio_1,
  output o_clken_en_gpio_2,
  output o_icgen_icg_timer_0,
  output o_icgen_icg_timer_1,
  output o_icgen_icg_uart_0,
  output o_icgen_icg_uart_1,
  output o_icgen_icg_spi,
  output o_icgen_icg_i2c,
  output o_icgen_icg_gpio_0,
  output o_icgen_icg_dma,
  output o_icgen_icg_pwm,
  output o_icgen_icg_gpio_1,
  output o_icgen_icg_gpio_2,
  output o_rstrel_rel_sbus,
  output o_rstrel_rel_pbus,
  output o_rstrel_rel_wdt,
  output o_rstrel_rel_timer_0,
  output o_rstrel_rel_timer_1,
  output o_rstrel_rel_uart_0,
  output o_rstrel_rel_uart_1,
  output o_rstrel_rel_spi,
  output o_rstrel_rel_i2c,
  output o_rstrel_rel_gpio_0,
  output o_rstrel_rel_dma,
  output o_rstrel_rel_rom,
  output o_rstrel_rel_ram,
  output o_rstrel_rel_pwm,
  output o_rstrel_rel_gpio_1,
  output o_rstrel_rel_gpio_2,
  output o_rstrel_rel_cpu,
  output o_apbblk_blk_timer_0,
  output o_apbblk_blk_timer_1,
  output o_apbblk_blk_uart_0,
  output o_apbblk_blk_uart_1,
  output o_apbblk_blk_spi,
  output o_apbblk_blk_i2c,
  output o_apbblk_blk_gpio_0,
  output o_apbblk_blk_dma,
  output o_apbblk_blk_pwm,
  output o_apbblk_blk_gpio_1,
  output o_apbblk_blk_gpio_2,
  input i_apbbusy_busy_timer_0,
  input i_apbbusy_busy_timer_1,
  input i_apbbusy_busy_uart_0,
  input i_apbbusy_busy_uart_1,
  input i_apbbusy_busy_spi,
  input i_apbbusy_busy_i2c,
  input i_apbbusy_busy_gpio_0,
  input i_apbbusy_busy_dma,
  input i_apbbusy_busy_pwm,
  input i_apbbusy_busy_gpio_1,
  input i_apbbusy_busy_gpio_2
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
  logic we_swrst;
  logic reg_swrst_sw_rst;
  logic nxt_swrst_sw_rst;
  logic [31:0] swrst_value;
  logic we_clken;
  logic reg_clken_en_timer_0;
  logic nxt_clken_en_timer_0;
  logic reg_clken_en_timer_1;
  logic nxt_clken_en_timer_1;
  logic reg_clken_en_uart_0;
  logic nxt_clken_en_uart_0;
  logic reg_clken_en_uart_1;
  logic nxt_clken_en_uart_1;
  logic reg_clken_en_spi;
  logic nxt_clken_en_spi;
  logic reg_clken_en_i2c;
  logic nxt_clken_en_i2c;
  logic reg_clken_en_gpio_0;
  logic nxt_clken_en_gpio_0;
  logic reg_clken_en_dma;
  logic nxt_clken_en_dma;
  logic reg_clken_en_pwm;
  logic nxt_clken_en_pwm;
  logic reg_clken_en_gpio_1;
  logic nxt_clken_en_gpio_1;
  logic reg_clken_en_gpio_2;
  logic nxt_clken_en_gpio_2;
  logic [31:0] clken_value;
  logic we_icgen;
  logic reg_icgen_icg_timer_0;
  logic nxt_icgen_icg_timer_0;
  logic reg_icgen_icg_timer_1;
  logic nxt_icgen_icg_timer_1;
  logic reg_icgen_icg_uart_0;
  logic nxt_icgen_icg_uart_0;
  logic reg_icgen_icg_uart_1;
  logic nxt_icgen_icg_uart_1;
  logic reg_icgen_icg_spi;
  logic nxt_icgen_icg_spi;
  logic reg_icgen_icg_i2c;
  logic nxt_icgen_icg_i2c;
  logic reg_icgen_icg_gpio_0;
  logic nxt_icgen_icg_gpio_0;
  logic reg_icgen_icg_dma;
  logic nxt_icgen_icg_dma;
  logic reg_icgen_icg_pwm;
  logic nxt_icgen_icg_pwm;
  logic reg_icgen_icg_gpio_1;
  logic nxt_icgen_icg_gpio_1;
  logic reg_icgen_icg_gpio_2;
  logic nxt_icgen_icg_gpio_2;
  logic [31:0] icgen_value;
  logic we_rstrel;
  logic reg_rstrel_rel_sbus;
  logic nxt_rstrel_rel_sbus;
  logic reg_rstrel_rel_pbus;
  logic nxt_rstrel_rel_pbus;
  logic reg_rstrel_rel_wdt;
  logic nxt_rstrel_rel_wdt;
  logic reg_rstrel_rel_timer_0;
  logic nxt_rstrel_rel_timer_0;
  logic reg_rstrel_rel_timer_1;
  logic nxt_rstrel_rel_timer_1;
  logic reg_rstrel_rel_uart_0;
  logic nxt_rstrel_rel_uart_0;
  logic reg_rstrel_rel_uart_1;
  logic nxt_rstrel_rel_uart_1;
  logic reg_rstrel_rel_spi;
  logic nxt_rstrel_rel_spi;
  logic reg_rstrel_rel_i2c;
  logic nxt_rstrel_rel_i2c;
  logic reg_rstrel_rel_gpio_0;
  logic nxt_rstrel_rel_gpio_0;
  logic reg_rstrel_rel_dma;
  logic nxt_rstrel_rel_dma;
  logic reg_rstrel_rel_rom;
  logic nxt_rstrel_rel_rom;
  logic reg_rstrel_rel_ram;
  logic nxt_rstrel_rel_ram;
  logic reg_rstrel_rel_pwm;
  logic nxt_rstrel_rel_pwm;
  logic reg_rstrel_rel_gpio_1;
  logic nxt_rstrel_rel_gpio_1;
  logic reg_rstrel_rel_gpio_2;
  logic nxt_rstrel_rel_gpio_2;
  logic reg_rstrel_rel_cpu;
  logic nxt_rstrel_rel_cpu;
  logic [31:0] rstrel_value;
  logic we_apbblk;
  logic reg_apbblk_blk_timer_0;
  logic nxt_apbblk_blk_timer_0;
  logic reg_apbblk_blk_timer_1;
  logic nxt_apbblk_blk_timer_1;
  logic reg_apbblk_blk_uart_0;
  logic nxt_apbblk_blk_uart_0;
  logic reg_apbblk_blk_uart_1;
  logic nxt_apbblk_blk_uart_1;
  logic reg_apbblk_blk_spi;
  logic nxt_apbblk_blk_spi;
  logic reg_apbblk_blk_i2c;
  logic nxt_apbblk_blk_i2c;
  logic reg_apbblk_blk_gpio_0;
  logic nxt_apbblk_blk_gpio_0;
  logic reg_apbblk_blk_dma;
  logic nxt_apbblk_blk_dma;
  logic reg_apbblk_blk_pwm;
  logic nxt_apbblk_blk_pwm;
  logic reg_apbblk_blk_gpio_1;
  logic nxt_apbblk_blk_gpio_1;
  logic reg_apbblk_blk_gpio_2;
  logic nxt_apbblk_blk_gpio_2;
  logic [31:0] apbblk_value;
  logic we_apbbusy;
  logic [31:0] apbbusy_value;
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
  assign we_swrst = apb_write_en & (reg_address == PARA_SWRST_OFFSET);
  assign we_clken = apb_write_en & (reg_address == PARA_CLKEN_OFFSET);
  assign we_icgen = apb_write_en & (reg_address == PARA_ICGEN_OFFSET);
  assign we_rstrel = apb_write_en & (reg_address == PARA_RSTREL_OFFSET);
  assign we_apbblk = apb_write_en & (reg_address == PARA_APBBLK_OFFSET);
  assign we_apbbusy = apb_write_en & (reg_address == PARA_APBBUSY_OFFSET);


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

  //Assignment for next value of swrst_sw_rst rw
  assign nxt_swrst_sw_rst = (we_swrst) ? reg_pwdata[0] : reg_swrst_sw_rst;
  //FF for bit swrst_sw_rst
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_swrst_sw_rst <= 1'h0;
    else
      reg_swrst_sw_rst <= nxt_swrst_sw_rst;
  end 
  assign o_swrst_sw_rst = reg_swrst_sw_rst;

  //--------------------------------------------------------------------
  //Combine the value of swrst
  //--------------------------------------------------------------------
  always_comb begin
    swrst_value[0] = reg_swrst_sw_rst;
    swrst_value[31:1] = '0;
  end  //Assignment for next value of clken_en_timer_0 rw
  assign nxt_clken_en_timer_0 = (we_clken) ? reg_pwdata[3] : reg_clken_en_timer_0;
  //FF for bit clken_en_timer_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_timer_0 <= 1'h1;
    else
      reg_clken_en_timer_0 <= nxt_clken_en_timer_0;
  end 
  assign o_clken_en_timer_0 = reg_clken_en_timer_0;
  //Assignment for next value of clken_en_timer_1 rw
  assign nxt_clken_en_timer_1 = (we_clken) ? reg_pwdata[4] : reg_clken_en_timer_1;
  //FF for bit clken_en_timer_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_timer_1 <= 1'h0;
    else
      reg_clken_en_timer_1 <= nxt_clken_en_timer_1;
  end 
  assign o_clken_en_timer_1 = reg_clken_en_timer_1;
  //Assignment for next value of clken_en_uart_0 rw
  assign nxt_clken_en_uart_0 = (we_clken) ? reg_pwdata[5] : reg_clken_en_uart_0;
  //FF for bit clken_en_uart_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_uart_0 <= 1'h1;
    else
      reg_clken_en_uart_0 <= nxt_clken_en_uart_0;
  end 
  assign o_clken_en_uart_0 = reg_clken_en_uart_0;
  //Assignment for next value of clken_en_uart_1 rw
  assign nxt_clken_en_uart_1 = (we_clken) ? reg_pwdata[6] : reg_clken_en_uart_1;
  //FF for bit clken_en_uart_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_uart_1 <= 1'h1;
    else
      reg_clken_en_uart_1 <= nxt_clken_en_uart_1;
  end 
  assign o_clken_en_uart_1 = reg_clken_en_uart_1;
  //Assignment for next value of clken_en_spi rw
  assign nxt_clken_en_spi = (we_clken) ? reg_pwdata[7] : reg_clken_en_spi;
  //FF for bit clken_en_spi
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_spi <= 1'h1;
    else
      reg_clken_en_spi <= nxt_clken_en_spi;
  end 
  assign o_clken_en_spi = reg_clken_en_spi;
  //Assignment for next value of clken_en_i2c rw
  assign nxt_clken_en_i2c = (we_clken) ? reg_pwdata[8] : reg_clken_en_i2c;
  //FF for bit clken_en_i2c
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_i2c <= 1'h1;
    else
      reg_clken_en_i2c <= nxt_clken_en_i2c;
  end 
  assign o_clken_en_i2c = reg_clken_en_i2c;
  //Assignment for next value of clken_en_gpio_0 rw
  assign nxt_clken_en_gpio_0 = (we_clken) ? reg_pwdata[9] : reg_clken_en_gpio_0;
  //FF for bit clken_en_gpio_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_gpio_0 <= 1'h1;
    else
      reg_clken_en_gpio_0 <= nxt_clken_en_gpio_0;
  end 
  assign o_clken_en_gpio_0 = reg_clken_en_gpio_0;
  //Assignment for next value of clken_en_dma rw
  assign nxt_clken_en_dma = (we_clken) ? reg_pwdata[10] : reg_clken_en_dma;
  //FF for bit clken_en_dma
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_dma <= 1'h1;
    else
      reg_clken_en_dma <= nxt_clken_en_dma;
  end 
  assign o_clken_en_dma = reg_clken_en_dma;
  //Assignment for next value of clken_en_pwm rw
  assign nxt_clken_en_pwm = (we_clken) ? reg_pwdata[15] : reg_clken_en_pwm;
  //FF for bit clken_en_pwm
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_pwm <= 1'h1;
    else
      reg_clken_en_pwm <= nxt_clken_en_pwm;
  end 
  assign o_clken_en_pwm = reg_clken_en_pwm;
  //Assignment for next value of clken_en_gpio_1 rw
  assign nxt_clken_en_gpio_1 = (we_clken) ? reg_pwdata[16] : reg_clken_en_gpio_1;
  //FF for bit clken_en_gpio_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_gpio_1 <= 1'h1;
    else
      reg_clken_en_gpio_1 <= nxt_clken_en_gpio_1;
  end 
  assign o_clken_en_gpio_1 = reg_clken_en_gpio_1;
  //Assignment for next value of clken_en_gpio_2 rw
  assign nxt_clken_en_gpio_2 = (we_clken) ? reg_pwdata[17] : reg_clken_en_gpio_2;
  //FF for bit clken_en_gpio_2
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_clken_en_gpio_2 <= 1'h1;
    else
      reg_clken_en_gpio_2 <= nxt_clken_en_gpio_2;
  end 
  assign o_clken_en_gpio_2 = reg_clken_en_gpio_2;

  //--------------------------------------------------------------------
  //Combine the value of clken
  //--------------------------------------------------------------------
  always_comb begin
    clken_value[2:0] = '0;
    clken_value[3] = reg_clken_en_timer_0;
    clken_value[4] = reg_clken_en_timer_1;
    clken_value[5] = reg_clken_en_uart_0;
    clken_value[6] = reg_clken_en_uart_1;
    clken_value[7] = reg_clken_en_spi;
    clken_value[8] = reg_clken_en_i2c;
    clken_value[9] = reg_clken_en_gpio_0;
    clken_value[10] = reg_clken_en_dma;
    clken_value[14:11] = '0;
    clken_value[15] = reg_clken_en_pwm;
    clken_value[16] = reg_clken_en_gpio_1;
    clken_value[17] = reg_clken_en_gpio_2;
    clken_value[31:18] = '0;
  end  //Assignment for next value of icgen_icg_timer_0 rw
  assign nxt_icgen_icg_timer_0 = (we_icgen) ? reg_pwdata[3] : reg_icgen_icg_timer_0;
  //FF for bit icgen_icg_timer_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_timer_0 <= 1'h0;
    else
      reg_icgen_icg_timer_0 <= nxt_icgen_icg_timer_0;
  end 
  assign o_icgen_icg_timer_0 = reg_icgen_icg_timer_0;
  //Assignment for next value of icgen_icg_timer_1 rw
  assign nxt_icgen_icg_timer_1 = (we_icgen) ? reg_pwdata[4] : reg_icgen_icg_timer_1;
  //FF for bit icgen_icg_timer_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_timer_1 <= 1'h0;
    else
      reg_icgen_icg_timer_1 <= nxt_icgen_icg_timer_1;
  end 
  assign o_icgen_icg_timer_1 = reg_icgen_icg_timer_1;
  //Assignment for next value of icgen_icg_uart_0 rw
  assign nxt_icgen_icg_uart_0 = (we_icgen) ? reg_pwdata[5] : reg_icgen_icg_uart_0;
  //FF for bit icgen_icg_uart_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_uart_0 <= 1'h0;
    else
      reg_icgen_icg_uart_0 <= nxt_icgen_icg_uart_0;
  end 
  assign o_icgen_icg_uart_0 = reg_icgen_icg_uart_0;
  //Assignment for next value of icgen_icg_uart_1 rw
  assign nxt_icgen_icg_uart_1 = (we_icgen) ? reg_pwdata[6] : reg_icgen_icg_uart_1;
  //FF for bit icgen_icg_uart_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_uart_1 <= 1'h0;
    else
      reg_icgen_icg_uart_1 <= nxt_icgen_icg_uart_1;
  end 
  assign o_icgen_icg_uart_1 = reg_icgen_icg_uart_1;
  //Assignment for next value of icgen_icg_spi rw
  assign nxt_icgen_icg_spi = (we_icgen) ? reg_pwdata[7] : reg_icgen_icg_spi;
  //FF for bit icgen_icg_spi
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_spi <= 1'h0;
    else
      reg_icgen_icg_spi <= nxt_icgen_icg_spi;
  end 
  assign o_icgen_icg_spi = reg_icgen_icg_spi;
  //Assignment for next value of icgen_icg_i2c rw
  assign nxt_icgen_icg_i2c = (we_icgen) ? reg_pwdata[8] : reg_icgen_icg_i2c;
  //FF for bit icgen_icg_i2c
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_i2c <= 1'h0;
    else
      reg_icgen_icg_i2c <= nxt_icgen_icg_i2c;
  end 
  assign o_icgen_icg_i2c = reg_icgen_icg_i2c;
  //Assignment for next value of icgen_icg_gpio_0 rw
  assign nxt_icgen_icg_gpio_0 = (we_icgen) ? reg_pwdata[9] : reg_icgen_icg_gpio_0;
  //FF for bit icgen_icg_gpio_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_gpio_0 <= 1'h0;
    else
      reg_icgen_icg_gpio_0 <= nxt_icgen_icg_gpio_0;
  end 
  assign o_icgen_icg_gpio_0 = reg_icgen_icg_gpio_0;
  //Assignment for next value of icgen_icg_dma rw
  assign nxt_icgen_icg_dma = (we_icgen) ? reg_pwdata[10] : reg_icgen_icg_dma;
  //FF for bit icgen_icg_dma
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_dma <= 1'h0;
    else
      reg_icgen_icg_dma <= nxt_icgen_icg_dma;
  end 
  assign o_icgen_icg_dma = reg_icgen_icg_dma;
  //Assignment for next value of icgen_icg_pwm rw
  assign nxt_icgen_icg_pwm = (we_icgen) ? reg_pwdata[15] : reg_icgen_icg_pwm;
  //FF for bit icgen_icg_pwm
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_pwm <= 1'h0;
    else
      reg_icgen_icg_pwm <= nxt_icgen_icg_pwm;
  end 
  assign o_icgen_icg_pwm = reg_icgen_icg_pwm;
  //Assignment for next value of icgen_icg_gpio_1 rw
  assign nxt_icgen_icg_gpio_1 = (we_icgen) ? reg_pwdata[16] : reg_icgen_icg_gpio_1;
  //FF for bit icgen_icg_gpio_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_gpio_1 <= 1'h0;
    else
      reg_icgen_icg_gpio_1 <= nxt_icgen_icg_gpio_1;
  end 
  assign o_icgen_icg_gpio_1 = reg_icgen_icg_gpio_1;
  //Assignment for next value of icgen_icg_gpio_2 rw
  assign nxt_icgen_icg_gpio_2 = (we_icgen) ? reg_pwdata[17] : reg_icgen_icg_gpio_2;
  //FF for bit icgen_icg_gpio_2
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_icgen_icg_gpio_2 <= 1'h0;
    else
      reg_icgen_icg_gpio_2 <= nxt_icgen_icg_gpio_2;
  end 
  assign o_icgen_icg_gpio_2 = reg_icgen_icg_gpio_2;

  //--------------------------------------------------------------------
  //Combine the value of icgen
  //--------------------------------------------------------------------
  always_comb begin
    icgen_value[2:0] = '0;
    icgen_value[3] = reg_icgen_icg_timer_0;
    icgen_value[4] = reg_icgen_icg_timer_1;
    icgen_value[5] = reg_icgen_icg_uart_0;
    icgen_value[6] = reg_icgen_icg_uart_1;
    icgen_value[7] = reg_icgen_icg_spi;
    icgen_value[8] = reg_icgen_icg_i2c;
    icgen_value[9] = reg_icgen_icg_gpio_0;
    icgen_value[10] = reg_icgen_icg_dma;
    icgen_value[14:11] = '0;
    icgen_value[15] = reg_icgen_icg_pwm;
    icgen_value[16] = reg_icgen_icg_gpio_1;
    icgen_value[17] = reg_icgen_icg_gpio_2;
    icgen_value[31:18] = '0;
  end  //Assignment for next value of rstrel_rel_sbus rw
  assign nxt_rstrel_rel_sbus = (we_rstrel) ? reg_pwdata[0] : reg_rstrel_rel_sbus;
  //FF for bit rstrel_rel_sbus
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_sbus <= 1'h0;
    else
      reg_rstrel_rel_sbus <= nxt_rstrel_rel_sbus;
  end 
  assign o_rstrel_rel_sbus = reg_rstrel_rel_sbus;
  //Assignment for next value of rstrel_rel_pbus rw
  assign nxt_rstrel_rel_pbus = (we_rstrel) ? reg_pwdata[1] : reg_rstrel_rel_pbus;
  //FF for bit rstrel_rel_pbus
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_pbus <= 1'h0;
    else
      reg_rstrel_rel_pbus <= nxt_rstrel_rel_pbus;
  end 
  assign o_rstrel_rel_pbus = reg_rstrel_rel_pbus;
  //Assignment for next value of rstrel_rel_wdt rw
  assign nxt_rstrel_rel_wdt = (we_rstrel) ? reg_pwdata[2] : reg_rstrel_rel_wdt;
  //FF for bit rstrel_rel_wdt
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_wdt <= 1'h0;
    else
      reg_rstrel_rel_wdt <= nxt_rstrel_rel_wdt;
  end 
  assign o_rstrel_rel_wdt = reg_rstrel_rel_wdt;
  //Assignment for next value of rstrel_rel_timer_0 rw
  assign nxt_rstrel_rel_timer_0 = (we_rstrel) ? reg_pwdata[3] : reg_rstrel_rel_timer_0;
  //FF for bit rstrel_rel_timer_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_timer_0 <= 1'h0;
    else
      reg_rstrel_rel_timer_0 <= nxt_rstrel_rel_timer_0;
  end 
  assign o_rstrel_rel_timer_0 = reg_rstrel_rel_timer_0;
  //Assignment for next value of rstrel_rel_timer_1 rw
  assign nxt_rstrel_rel_timer_1 = (we_rstrel) ? reg_pwdata[4] : reg_rstrel_rel_timer_1;
  //FF for bit rstrel_rel_timer_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_timer_1 <= 1'h0;
    else
      reg_rstrel_rel_timer_1 <= nxt_rstrel_rel_timer_1;
  end 
  assign o_rstrel_rel_timer_1 = reg_rstrel_rel_timer_1;
  //Assignment for next value of rstrel_rel_uart_0 rw
  assign nxt_rstrel_rel_uart_0 = (we_rstrel) ? reg_pwdata[5] : reg_rstrel_rel_uart_0;
  //FF for bit rstrel_rel_uart_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_uart_0 <= 1'h0;
    else
      reg_rstrel_rel_uart_0 <= nxt_rstrel_rel_uart_0;
  end 
  assign o_rstrel_rel_uart_0 = reg_rstrel_rel_uart_0;
  //Assignment for next value of rstrel_rel_uart_1 rw
  assign nxt_rstrel_rel_uart_1 = (we_rstrel) ? reg_pwdata[6] : reg_rstrel_rel_uart_1;
  //FF for bit rstrel_rel_uart_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_uart_1 <= 1'h0;
    else
      reg_rstrel_rel_uart_1 <= nxt_rstrel_rel_uart_1;
  end 
  assign o_rstrel_rel_uart_1 = reg_rstrel_rel_uart_1;
  //Assignment for next value of rstrel_rel_spi rw
  assign nxt_rstrel_rel_spi = (we_rstrel) ? reg_pwdata[7] : reg_rstrel_rel_spi;
  //FF for bit rstrel_rel_spi
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_spi <= 1'h0;
    else
      reg_rstrel_rel_spi <= nxt_rstrel_rel_spi;
  end 
  assign o_rstrel_rel_spi = reg_rstrel_rel_spi;
  //Assignment for next value of rstrel_rel_i2c rw
  assign nxt_rstrel_rel_i2c = (we_rstrel) ? reg_pwdata[8] : reg_rstrel_rel_i2c;
  //FF for bit rstrel_rel_i2c
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_i2c <= 1'h0;
    else
      reg_rstrel_rel_i2c <= nxt_rstrel_rel_i2c;
  end 
  assign o_rstrel_rel_i2c = reg_rstrel_rel_i2c;
  //Assignment for next value of rstrel_rel_gpio_0 rw
  assign nxt_rstrel_rel_gpio_0 = (we_rstrel) ? reg_pwdata[9] : reg_rstrel_rel_gpio_0;
  //FF for bit rstrel_rel_gpio_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_gpio_0 <= 1'h0;
    else
      reg_rstrel_rel_gpio_0 <= nxt_rstrel_rel_gpio_0;
  end 
  assign o_rstrel_rel_gpio_0 = reg_rstrel_rel_gpio_0;
  //Assignment for next value of rstrel_rel_dma rw
  assign nxt_rstrel_rel_dma = (we_rstrel) ? reg_pwdata[10] : reg_rstrel_rel_dma;
  //FF for bit rstrel_rel_dma
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_dma <= 1'h0;
    else
      reg_rstrel_rel_dma <= nxt_rstrel_rel_dma;
  end 
  assign o_rstrel_rel_dma = reg_rstrel_rel_dma;
  //Assignment for next value of rstrel_rel_rom rw
  assign nxt_rstrel_rel_rom = (we_rstrel) ? reg_pwdata[11] : reg_rstrel_rel_rom;
  //FF for bit rstrel_rel_rom
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_rom <= 1'h0;
    else
      reg_rstrel_rel_rom <= nxt_rstrel_rel_rom;
  end 
  assign o_rstrel_rel_rom = reg_rstrel_rel_rom;
  //Assignment for next value of rstrel_rel_ram rw
  assign nxt_rstrel_rel_ram = (we_rstrel) ? reg_pwdata[12] : reg_rstrel_rel_ram;
  //FF for bit rstrel_rel_ram
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_ram <= 1'h0;
    else
      reg_rstrel_rel_ram <= nxt_rstrel_rel_ram;
  end 
  assign o_rstrel_rel_ram = reg_rstrel_rel_ram;
  //Assignment for next value of rstrel_rel_pwm rw
  assign nxt_rstrel_rel_pwm = (we_rstrel) ? reg_pwdata[15] : reg_rstrel_rel_pwm;
  //FF for bit rstrel_rel_pwm
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_pwm <= 1'h0;
    else
      reg_rstrel_rel_pwm <= nxt_rstrel_rel_pwm;
  end 
  assign o_rstrel_rel_pwm = reg_rstrel_rel_pwm;
  //Assignment for next value of rstrel_rel_gpio_1 rw
  assign nxt_rstrel_rel_gpio_1 = (we_rstrel) ? reg_pwdata[16] : reg_rstrel_rel_gpio_1;
  //FF for bit rstrel_rel_gpio_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_gpio_1 <= 1'h0;
    else
      reg_rstrel_rel_gpio_1 <= nxt_rstrel_rel_gpio_1;
  end 
  assign o_rstrel_rel_gpio_1 = reg_rstrel_rel_gpio_1;
  //Assignment for next value of rstrel_rel_gpio_2 rw
  assign nxt_rstrel_rel_gpio_2 = (we_rstrel) ? reg_pwdata[17] : reg_rstrel_rel_gpio_2;
  //FF for bit rstrel_rel_gpio_2
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_gpio_2 <= 1'h0;
    else
      reg_rstrel_rel_gpio_2 <= nxt_rstrel_rel_gpio_2;
  end 
  assign o_rstrel_rel_gpio_2 = reg_rstrel_rel_gpio_2;
  //Assignment for next value of rstrel_rel_cpu rw
  assign nxt_rstrel_rel_cpu = (we_rstrel) ? reg_pwdata[31] : reg_rstrel_rel_cpu;
  //FF for bit rstrel_rel_cpu
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_rstrel_rel_cpu <= 1'h0;
    else
      reg_rstrel_rel_cpu <= nxt_rstrel_rel_cpu;
  end 
  assign o_rstrel_rel_cpu = reg_rstrel_rel_cpu;

  //--------------------------------------------------------------------
  //Combine the value of rstrel
  //--------------------------------------------------------------------
  always_comb begin
    rstrel_value[0] = reg_rstrel_rel_sbus;
    rstrel_value[1] = reg_rstrel_rel_pbus;
    rstrel_value[2] = reg_rstrel_rel_wdt;
    rstrel_value[3] = reg_rstrel_rel_timer_0;
    rstrel_value[4] = reg_rstrel_rel_timer_1;
    rstrel_value[5] = reg_rstrel_rel_uart_0;
    rstrel_value[6] = reg_rstrel_rel_uart_1;
    rstrel_value[7] = reg_rstrel_rel_spi;
    rstrel_value[8] = reg_rstrel_rel_i2c;
    rstrel_value[9] = reg_rstrel_rel_gpio_0;
    rstrel_value[10] = reg_rstrel_rel_dma;
    rstrel_value[11] = reg_rstrel_rel_rom;
    rstrel_value[12] = reg_rstrel_rel_ram;
    rstrel_value[14:13] = '0;
    rstrel_value[15] = reg_rstrel_rel_pwm;
    rstrel_value[16] = reg_rstrel_rel_gpio_1;
    rstrel_value[17] = reg_rstrel_rel_gpio_2;
    rstrel_value[30:18] = '0;
    rstrel_value[31] = reg_rstrel_rel_cpu;
  end  //Assignment for next value of apbblk_blk_timer_0 rw
  assign nxt_apbblk_blk_timer_0 = (we_apbblk) ? reg_pwdata[3] : reg_apbblk_blk_timer_0;
  //FF for bit apbblk_blk_timer_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_timer_0 <= 1'h1;
    else
      reg_apbblk_blk_timer_0 <= nxt_apbblk_blk_timer_0;
  end 
  assign o_apbblk_blk_timer_0 = reg_apbblk_blk_timer_0;
  //Assignment for next value of apbblk_blk_timer_1 rw
  assign nxt_apbblk_blk_timer_1 = (we_apbblk) ? reg_pwdata[4] : reg_apbblk_blk_timer_1;
  //FF for bit apbblk_blk_timer_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_timer_1 <= 1'h1;
    else
      reg_apbblk_blk_timer_1 <= nxt_apbblk_blk_timer_1;
  end 
  assign o_apbblk_blk_timer_1 = reg_apbblk_blk_timer_1;
  //Assignment for next value of apbblk_blk_uart_0 rw
  assign nxt_apbblk_blk_uart_0 = (we_apbblk) ? reg_pwdata[5] : reg_apbblk_blk_uart_0;
  //FF for bit apbblk_blk_uart_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_uart_0 <= 1'h1;
    else
      reg_apbblk_blk_uart_0 <= nxt_apbblk_blk_uart_0;
  end 
  assign o_apbblk_blk_uart_0 = reg_apbblk_blk_uart_0;
  //Assignment for next value of apbblk_blk_uart_1 rw
  assign nxt_apbblk_blk_uart_1 = (we_apbblk) ? reg_pwdata[6] : reg_apbblk_blk_uart_1;
  //FF for bit apbblk_blk_uart_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_uart_1 <= 1'h1;
    else
      reg_apbblk_blk_uart_1 <= nxt_apbblk_blk_uart_1;
  end 
  assign o_apbblk_blk_uart_1 = reg_apbblk_blk_uart_1;
  //Assignment for next value of apbblk_blk_spi rw
  assign nxt_apbblk_blk_spi = (we_apbblk) ? reg_pwdata[7] : reg_apbblk_blk_spi;
  //FF for bit apbblk_blk_spi
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_spi <= 1'h1;
    else
      reg_apbblk_blk_spi <= nxt_apbblk_blk_spi;
  end 
  assign o_apbblk_blk_spi = reg_apbblk_blk_spi;
  //Assignment for next value of apbblk_blk_i2c rw
  assign nxt_apbblk_blk_i2c = (we_apbblk) ? reg_pwdata[8] : reg_apbblk_blk_i2c;
  //FF for bit apbblk_blk_i2c
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_i2c <= 1'h1;
    else
      reg_apbblk_blk_i2c <= nxt_apbblk_blk_i2c;
  end 
  assign o_apbblk_blk_i2c = reg_apbblk_blk_i2c;
  //Assignment for next value of apbblk_blk_gpio_0 rw
  assign nxt_apbblk_blk_gpio_0 = (we_apbblk) ? reg_pwdata[9] : reg_apbblk_blk_gpio_0;
  //FF for bit apbblk_blk_gpio_0
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_gpio_0 <= 1'h1;
    else
      reg_apbblk_blk_gpio_0 <= nxt_apbblk_blk_gpio_0;
  end 
  assign o_apbblk_blk_gpio_0 = reg_apbblk_blk_gpio_0;
  //Assignment for next value of apbblk_blk_dma rw
  assign nxt_apbblk_blk_dma = (we_apbblk) ? reg_pwdata[10] : reg_apbblk_blk_dma;
  //FF for bit apbblk_blk_dma
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_dma <= 1'h1;
    else
      reg_apbblk_blk_dma <= nxt_apbblk_blk_dma;
  end 
  assign o_apbblk_blk_dma = reg_apbblk_blk_dma;
  //Assignment for next value of apbblk_blk_pwm rw
  assign nxt_apbblk_blk_pwm = (we_apbblk) ? reg_pwdata[15] : reg_apbblk_blk_pwm;
  //FF for bit apbblk_blk_pwm
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_pwm <= 1'h1;
    else
      reg_apbblk_blk_pwm <= nxt_apbblk_blk_pwm;
  end 
  assign o_apbblk_blk_pwm = reg_apbblk_blk_pwm;
  //Assignment for next value of apbblk_blk_gpio_1 rw
  assign nxt_apbblk_blk_gpio_1 = (we_apbblk) ? reg_pwdata[16] : reg_apbblk_blk_gpio_1;
  //FF for bit apbblk_blk_gpio_1
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_gpio_1 <= 1'h1;
    else
      reg_apbblk_blk_gpio_1 <= nxt_apbblk_blk_gpio_1;
  end 
  assign o_apbblk_blk_gpio_1 = reg_apbblk_blk_gpio_1;
  //Assignment for next value of apbblk_blk_gpio_2 rw
  assign nxt_apbblk_blk_gpio_2 = (we_apbblk) ? reg_pwdata[17] : reg_apbblk_blk_gpio_2;
  //FF for bit apbblk_blk_gpio_2
  always_ff @ (posedge i_bus_clk, negedge i_bus_rstn) begin //FF for each bit
    if(!i_bus_rstn) 
      reg_apbblk_blk_gpio_2 <= 1'h1;
    else
      reg_apbblk_blk_gpio_2 <= nxt_apbblk_blk_gpio_2;
  end 
  assign o_apbblk_blk_gpio_2 = reg_apbblk_blk_gpio_2;

  //--------------------------------------------------------------------
  //Combine the value of apbblk
  //--------------------------------------------------------------------
  always_comb begin
    apbblk_value[2:0] = '0;
    apbblk_value[3] = reg_apbblk_blk_timer_0;
    apbblk_value[4] = reg_apbblk_blk_timer_1;
    apbblk_value[5] = reg_apbblk_blk_uart_0;
    apbblk_value[6] = reg_apbblk_blk_uart_1;
    apbblk_value[7] = reg_apbblk_blk_spi;
    apbblk_value[8] = reg_apbblk_blk_i2c;
    apbblk_value[9] = reg_apbblk_blk_gpio_0;
    apbblk_value[10] = reg_apbblk_blk_dma;
    apbblk_value[14:11] = '0;
    apbblk_value[15] = reg_apbblk_blk_pwm;
    apbblk_value[16] = reg_apbblk_blk_gpio_1;
    apbblk_value[17] = reg_apbblk_blk_gpio_2;
    apbblk_value[31:18] = '0;
  end
  //--------------------------------------------------------------------
  //Combine the value of apbbusy
  //--------------------------------------------------------------------
  always_comb begin
    apbbusy_value[2:0] = '0;
    apbbusy_value[3] = i_apbbusy_busy_timer_0;
    apbbusy_value[4] = i_apbbusy_busy_timer_1;
    apbbusy_value[5] = i_apbbusy_busy_uart_0;
    apbbusy_value[6] = i_apbbusy_busy_uart_1;
    apbbusy_value[7] = i_apbbusy_busy_spi;
    apbbusy_value[8] = i_apbbusy_busy_i2c;
    apbbusy_value[9] = i_apbbusy_busy_gpio_0;
    apbbusy_value[10] = i_apbbusy_busy_dma;
    apbbusy_value[14:11] = '0;
    apbbusy_value[15] = i_apbbusy_busy_pwm;
    apbbusy_value[16] = i_apbbusy_busy_gpio_1;
    apbbusy_value[17] = i_apbbusy_busy_gpio_2;
    apbbusy_value[31:18] = '0;
  end
  //--------------------------------------------------------------------
  //O_PRDATA phase
  //--------------------------------------------------------------------
  always_comb begin
    case (reg_address)
      PARA_SWRST_OFFSET: nxt_prdata = swrst_value;
      PARA_CLKEN_OFFSET: nxt_prdata = clken_value;
      PARA_ICGEN_OFFSET: nxt_prdata = icgen_value;
      PARA_RSTREL_OFFSET: nxt_prdata = rstrel_value;
      PARA_APBBLK_OFFSET: nxt_prdata = apbblk_value;
      PARA_APBBUSY_OFFSET: nxt_prdata = apbbusy_value;
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

endmodule: m_qnsc_scrc_csr