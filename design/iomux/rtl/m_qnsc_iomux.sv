/*
 * Project      : QSOC
 * Author       : Vinh (user)
 * AI Flow      : VLSIT RTL Generator AI Automation Flow (style only; names follow
 *                QNSC_RTL_Design_Naming_Rule V1.2, designer decision 2026-11-05)
 * AI Flow Page : https://github.com/nguyenquanicd/VLSIT_ASIC_SOC_AI_SKILLS
 * Date         : 2026-11-05
 * Description  : IO pin multiplexer of QSOC, Pad List v4 (IOPAD_Pin_Summary_v4,
 *                SYSCSR MAS V4 Table 6-8). Combinational: no clock, no reset, no
 *                register.
 *
 * Select
 *   i_iomux_sel = SYSCSR o_iomux_sel[43:0] (IOMUX_SEL_0 @0x28 = fields 0-15,
 *   IOMUX_SEL_1 @0x2C = fields 16-21). Muxed pad f uses field
 *   i_iomux_sel[2f+1:2f]: b00 = default function (reset value), b01, b10 = the
 *   other functions, a code with no function = unassigned: OE = 0, IE = 0
 *   (pad Hi-Z, input buffer off). The select is quasi-static: firmware changes a
 *   field only while the IPs on that pad are idle, so it is not synchronized.
 *
 * Pads (index k of o_pad_* / i_pad_in, the order of the pad ring)
 *   k   pin    field  b00        b01        b10
 *   0   PIN5   fixed  TCK
 *   1   PIN6   fixed  TMS
 *   2   PIN7   fixed  TDI
 *   3   PIN8   fixed  TDO
 *   4   PIN9   fixed  TRSTN
 *   5   PIN10  0      UART0_TX   GPIO0_7
 *   6   PIN11  1      UART0_RX   GPIO0_6
 *   7   PIN12  fixed  GPIO0_5
 *   8   PIN15  2      GPIO1_7    SPI_SCK
 *   9   PIN16  3      GPIO1_6    SPI_CSB
 *   10  PIN17  4      GPIO1_5    SPI_SD0
 *   11  PIN18  5      GPIO1_4    SPI_SD1
 *   12  PIN19  6      GPIO1_3    UART1_TX
 *   13  PIN20  7      GPIO1_2    UART1_RX
 *   14  PIN21  8      I2C_SCL    GPIO0_4
 *   15  PIN22  9      I2C_SDA    GPIO0_3
 *   16  PIN23  10     GPIO1_1    PWM_0      SPID_SCK
 *   17  PIN24  11     GPIO1_0    PWM_1      SPID_CSB
 *   18  PIN25  12     GPIO2_7    PWM_2      SPID_MOSI
 *   19  PIN26  13     GPIO2_6    PWM_3      SPID_MISO
 *   20  PIN29  14     GPIO2_5    PWM_4
 *   21  PIN30  15     GPIO2_4    PWM_5
 *   22  PIN31  16     GPIO2_3    PWM_6
 *   23  PIN32  17     GPIO2_2    PWM_7
 *   24  PIN33  18     TIM_EXT0   GPIO0_2
 *   25  PIN34  19     TIM_EXT1   GPIO0_1
 *   26  PIN38  20     GPIO2_1    TIM_EXT2
 *   27  PIN39  21     GPIO2_0    TIM_EXT3
 *   28  PIN40  fixed  GPIO0_0
 *   Not here: OSCIN PIN1 (SCRC), RSTN PIN4 (SCRC), DBG_EN PIN35 (SYSDBG,
 *   SYSCSR) and the power pads.
 *
 * Pad controls (vendor pad cell PBIDIR: A, OE, IE active high, Y)
 *   GPIO       A = gpio out, OE = gpio dir, IE = 1
 *   UART TX    OE = 1: SOUT has no enable and idles at 1
 *   I2C        A = wrapper data (0), OE = wrapper enable (active high): open drain
 *   SPI host   SCK, CSB, SD0, SD1: A and OE from spi_host cio_*_o / cio_*_en_o;
 *              SD0 = MOSI, SD1 = MISO in Standard SPI. SD2/SD3 are tied off in
 *              the SPI wrapper
 *   SPI device SCK, CSB, MOSI in (IE = 1), MISO out with spi_device's enable
 *   PWM        OE = 1, IE = 0. TIM_EXT: IE = 1 (synchronized in the PWM wrapper)
 *   JTAG       fixed pads, always on the TAP; TDO with the TAP's enable
 *
 * Idle value of an IP input that no pad selects
 *   UART RX = 1 (a 0 would be a start bit), I2C SCL/SDA = 1 (bus released),
 *   SPI device CSB = 1 (not selected), SCK = 0, MOSI = 0, SPI host SD = 0,
 *   GPIO in = 0, TIM_EXT = 0.
 *
 * The pad cells are not in this block: o_pad_out / o_pad_oe / o_pad_ie /
 * i_pad_in go to the pad ring in m_qnsc_chip.
 */
`timescale 1ns/1ps

module m_qnsc_iomux (
  // ---- select (SYSCSR o_iomux_sel), field f = [2f+1:2f] ----------------------
  input  logic [43:0] i_iomux_sel,

  // ---- GPIO 0 (apb_gpio gpio_out / gpio_dir / gpio_in) -----------------------
  input  logic [7:0]  i_gpio_0_out,
  input  logic [7:0]  i_gpio_0_oe,
  output logic [7:0]  o_gpio_0_in,

  // ---- GPIO 1 ----------------------------------------------------------------
  input  logic [7:0]  i_gpio_1_out,
  input  logic [7:0]  i_gpio_1_oe,
  output logic [7:0]  o_gpio_1_in,

  // ---- GPIO 2 ----------------------------------------------------------------
  input  logic [7:0]  i_gpio_2_out,
  input  logic [7:0]  i_gpio_2_oe,
  output logic [7:0]  o_gpio_2_in,

  // ---- UART 0 ----------------------------------------------------------------
  input  logic        i_uart_0_tx,
  output logic        o_uart_0_rx,

  // ---- UART 1 ----------------------------------------------------------------
  input  logic        i_uart_1_tx,
  output logic        o_uart_1_rx,

  // ---- SPI host (Standard SPI: SD0 = MOSI out, SD1 = MISO in) ----------------
  input  logic        i_spih_sck,
  input  logic        i_spih_sck_oe,
  input  logic        i_spih_csb,
  input  logic        i_spih_csb_oe,
  input  logic [1:0]  i_spih_sd,
  input  logic [1:0]  i_spih_sd_oe,
  output logic [1:0]  o_spih_sd,

  // ---- SPI device (Standard SPI) ---------------------------------------------
  output logic        o_spid_sck,
  output logic        o_spid_csb,
  output logic        o_spid_mosi,
  input  logic        i_spid_miso,
  input  logic        i_spid_miso_oe,

  // ---- I2C (open drain, OE active high from m_qnsc_wrap_i2c) -----------------
  input  logic        i_i2c_scl,
  input  logic        i_i2c_scl_oe,
  output logic        o_i2c_scl,
  input  logic        i_i2c_sda,
  input  logic        i_i2c_sda_oe,
  output logic        o_i2c_sda,

  // ---- PWM (o_pad_pwm = {timer1 ch, timer0 ch}) and timer external inputs ----
  input  logic [7:0]  i_pwm,
  output logic [3:0]  o_tim_ext,

  // ---- JTAG (SYSDBG TAP) -----------------------------------------------------
  output logic        o_jtag_tck,
  output logic        o_jtag_tms,
  output logic        o_jtag_tdi,
  input  logic        i_jtag_tdo,
  input  logic        i_jtag_tdo_oe,
  output logic        o_jtag_trst_n,

  // ---- pad cells: A, OE, IE (active high), Y ---------------------------------
  output logic [28:0] o_pad_out,
  output logic [28:0] o_pad_oe,
  output logic [28:0] o_pad_ie,
  input  logic [28:0] i_pad_in
);

  // ---- select codes of a 2-bit field (Pad List v4 columns b00, b01, b10) ------
  localparam logic [1:0] C_SEL_B00 = 2'b00;
  localparam logic [1:0] C_SEL_B01 = 2'b01;
  localparam logic [1:0] C_SEL_B10 = 2'b10;

  // ---- pad index k of each package pin ---------------------------------------
  localparam int C_PAD_PIN_5  = 0;
  localparam int C_PAD_PIN_6  = 1;
  localparam int C_PAD_PIN_7  = 2;
  localparam int C_PAD_PIN_8  = 3;
  localparam int C_PAD_PIN_9  = 4;
  localparam int C_PAD_PIN_10 = 5;
  localparam int C_PAD_PIN_11 = 6;
  localparam int C_PAD_PIN_12 = 7;
  localparam int C_PAD_PIN_15 = 8;
  localparam int C_PAD_PIN_16 = 9;
  localparam int C_PAD_PIN_17 = 10;
  localparam int C_PAD_PIN_18 = 11;
  localparam int C_PAD_PIN_19 = 12;
  localparam int C_PAD_PIN_20 = 13;
  localparam int C_PAD_PIN_21 = 14;
  localparam int C_PAD_PIN_22 = 15;
  localparam int C_PAD_PIN_23 = 16;
  localparam int C_PAD_PIN_24 = 17;
  localparam int C_PAD_PIN_25 = 18;
  localparam int C_PAD_PIN_26 = 19;
  localparam int C_PAD_PIN_29 = 20;
  localparam int C_PAD_PIN_30 = 21;
  localparam int C_PAD_PIN_31 = 22;
  localparam int C_PAD_PIN_32 = 23;
  localparam int C_PAD_PIN_33 = 24;
  localparam int C_PAD_PIN_34 = 25;
  localparam int C_PAD_PIN_38 = 26;
  localparam int C_PAD_PIN_39 = 27;
  localparam int C_PAD_PIN_40 = 28;

  // ---- select field of each muxed pin ----------------------------------------
  logic [1:0] w_sel_pin_10;
  logic [1:0] w_sel_pin_11;
  logic [1:0] w_sel_pin_15;
  logic [1:0] w_sel_pin_16;
  logic [1:0] w_sel_pin_17;
  logic [1:0] w_sel_pin_18;
  logic [1:0] w_sel_pin_19;
  logic [1:0] w_sel_pin_20;
  logic [1:0] w_sel_pin_21;
  logic [1:0] w_sel_pin_22;
  logic [1:0] w_sel_pin_23;
  logic [1:0] w_sel_pin_24;
  logic [1:0] w_sel_pin_25;
  logic [1:0] w_sel_pin_26;
  logic [1:0] w_sel_pin_29;
  logic [1:0] w_sel_pin_30;
  logic [1:0] w_sel_pin_31;
  logic [1:0] w_sel_pin_32;
  logic [1:0] w_sel_pin_33;
  logic [1:0] w_sel_pin_34;
  logic [1:0] w_sel_pin_38;
  logic [1:0] w_sel_pin_39;

  // Field split: IOMUX_SEL_0 holds fields 0-15 (pins 10 to 30), IOMUX_SEL_1
  // fields 16-21 (pins 31 to 39), in pin order (SYSCSR MAS V4 Table 6-8).
  assign w_sel_pin_10 = i_iomux_sel[1:0];    // field 0
  assign w_sel_pin_11 = i_iomux_sel[3:2];    // field 1
  assign w_sel_pin_15 = i_iomux_sel[5:4];    // field 2
  assign w_sel_pin_16 = i_iomux_sel[7:6];    // field 3
  assign w_sel_pin_17 = i_iomux_sel[9:8];    // field 4
  assign w_sel_pin_18 = i_iomux_sel[11:10];  // field 5
  assign w_sel_pin_19 = i_iomux_sel[13:12];  // field 6
  assign w_sel_pin_20 = i_iomux_sel[15:14];  // field 7
  assign w_sel_pin_21 = i_iomux_sel[17:16];  // field 8
  assign w_sel_pin_22 = i_iomux_sel[19:18];  // field 9
  assign w_sel_pin_23 = i_iomux_sel[21:20];  // field 10
  assign w_sel_pin_24 = i_iomux_sel[23:22];  // field 11
  assign w_sel_pin_25 = i_iomux_sel[25:24];  // field 12
  assign w_sel_pin_26 = i_iomux_sel[27:26];  // field 13
  assign w_sel_pin_29 = i_iomux_sel[29:28];  // field 14
  assign w_sel_pin_30 = i_iomux_sel[31:30];  // field 15
  assign w_sel_pin_31 = i_iomux_sel[33:32];  // field 16
  assign w_sel_pin_32 = i_iomux_sel[35:34];  // field 17
  assign w_sel_pin_33 = i_iomux_sel[37:36];  // field 18
  assign w_sel_pin_34 = i_iomux_sel[39:38];  // field 19
  assign w_sel_pin_38 = i_iomux_sel[41:40];  // field 20
  assign w_sel_pin_39 = i_iomux_sel[43:42];  // field 21

  // Pad drive: A, OE and IE of every pad come from the function its field
  // selects (or its one function for a fixed pad). Every pad starts with
  // A = 0, OE = 0, IE = 0, which is also what an unassigned code leaves.
  always_comb begin : p_com_pad
    o_pad_out = '0;
    o_pad_oe  = '0;
    o_pad_ie  = '0;

    // ---- fixed: JTAG, PIN5-9 -------------------------------------------------
    o_pad_ie[C_PAD_PIN_5]  = 1'b1;           // TCK
    o_pad_ie[C_PAD_PIN_6]  = 1'b1;           // TMS
    o_pad_ie[C_PAD_PIN_7]  = 1'b1;           // TDI
    o_pad_out[C_PAD_PIN_8] = i_jtag_tdo;     // TDO, output only
    o_pad_oe[C_PAD_PIN_8]  = i_jtag_tdo_oe;
    o_pad_ie[C_PAD_PIN_9]  = 1'b1;           // TRSTN

    // ---- PIN10: UART0_TX / GPIO0_7 ------------------------------------------
    case (w_sel_pin_10)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_10] = i_uart_0_tx;
        o_pad_oe[C_PAD_PIN_10]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_10] = i_gpio_0_out[7];
        o_pad_oe[C_PAD_PIN_10]  = i_gpio_0_oe[7];
        o_pad_ie[C_PAD_PIN_10]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_10]  = 1'b0;
      end
    endcase

    // ---- PIN11: UART0_RX / GPIO0_6 ------------------------------------------
    case (w_sel_pin_11)
      C_SEL_B00: begin
        o_pad_ie[C_PAD_PIN_11]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_11] = i_gpio_0_out[6];
        o_pad_oe[C_PAD_PIN_11]  = i_gpio_0_oe[6];
        o_pad_ie[C_PAD_PIN_11]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_11]  = 1'b0;
      end
    endcase

    // ---- PIN12: GPIO0_5, fixed ----------------------------------------------
    o_pad_out[C_PAD_PIN_12] = i_gpio_0_out[5];
    o_pad_oe[C_PAD_PIN_12]  = i_gpio_0_oe[5];
    o_pad_ie[C_PAD_PIN_12]  = 1'b1;

    // ---- PIN15: GPIO1_7 / SPI_SCK -------------------------------------------
    case (w_sel_pin_15)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_15] = i_gpio_1_out[7];
        o_pad_oe[C_PAD_PIN_15]  = i_gpio_1_oe[7];
        o_pad_ie[C_PAD_PIN_15]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_15] = i_spih_sck;
        o_pad_oe[C_PAD_PIN_15]  = i_spih_sck_oe;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_15]  = 1'b0;
      end
    endcase

    // ---- PIN16: GPIO1_6 / SPI_CSB -------------------------------------------
    case (w_sel_pin_16)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_16] = i_gpio_1_out[6];
        o_pad_oe[C_PAD_PIN_16]  = i_gpio_1_oe[6];
        o_pad_ie[C_PAD_PIN_16]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_16] = i_spih_csb;
        o_pad_oe[C_PAD_PIN_16]  = i_spih_csb_oe;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_16]  = 1'b0;
      end
    endcase

    // ---- PIN17: GPIO1_5 / SPI_SD0 -------------------------------------------
    case (w_sel_pin_17)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_17] = i_gpio_1_out[5];
        o_pad_oe[C_PAD_PIN_17]  = i_gpio_1_oe[5];
        o_pad_ie[C_PAD_PIN_17]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_17] = i_spih_sd[0];
        o_pad_oe[C_PAD_PIN_17]  = i_spih_sd_oe[0];
        o_pad_ie[C_PAD_PIN_17]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_17]  = 1'b0;
      end
    endcase

    // ---- PIN18: GPIO1_4 / SPI_SD1 -------------------------------------------
    case (w_sel_pin_18)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_18] = i_gpio_1_out[4];
        o_pad_oe[C_PAD_PIN_18]  = i_gpio_1_oe[4];
        o_pad_ie[C_PAD_PIN_18]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_18] = i_spih_sd[1];
        o_pad_oe[C_PAD_PIN_18]  = i_spih_sd_oe[1];
        o_pad_ie[C_PAD_PIN_18]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_18]  = 1'b0;
      end
    endcase

    // ---- PIN19: GPIO1_3 / UART1_TX ------------------------------------------
    case (w_sel_pin_19)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_19] = i_gpio_1_out[3];
        o_pad_oe[C_PAD_PIN_19]  = i_gpio_1_oe[3];
        o_pad_ie[C_PAD_PIN_19]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_19] = i_uart_1_tx;
        o_pad_oe[C_PAD_PIN_19]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_19]  = 1'b0;
      end
    endcase

    // ---- PIN20: GPIO1_2 / UART1_RX ------------------------------------------
    case (w_sel_pin_20)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_20] = i_gpio_1_out[2];
        o_pad_oe[C_PAD_PIN_20]  = i_gpio_1_oe[2];
        o_pad_ie[C_PAD_PIN_20]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_ie[C_PAD_PIN_20]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_20]  = 1'b0;
      end
    endcase

    // ---- PIN21: I2C_SCL / GPIO0_4 -------------------------------------------
    case (w_sel_pin_21)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_21] = i_i2c_scl;
        o_pad_oe[C_PAD_PIN_21]  = i_i2c_scl_oe;
        o_pad_ie[C_PAD_PIN_21]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_21] = i_gpio_0_out[4];
        o_pad_oe[C_PAD_PIN_21]  = i_gpio_0_oe[4];
        o_pad_ie[C_PAD_PIN_21]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_21]  = 1'b0;
      end
    endcase

    // ---- PIN22: I2C_SDA / GPIO0_3 -------------------------------------------
    case (w_sel_pin_22)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_22] = i_i2c_sda;
        o_pad_oe[C_PAD_PIN_22]  = i_i2c_sda_oe;
        o_pad_ie[C_PAD_PIN_22]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_22] = i_gpio_0_out[3];
        o_pad_oe[C_PAD_PIN_22]  = i_gpio_0_oe[3];
        o_pad_ie[C_PAD_PIN_22]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_22]  = 1'b0;
      end
    endcase

    // ---- PIN23: GPIO1_1 / PWM_0 / SPID_SCK ----------------------------------
    case (w_sel_pin_23)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_23] = i_gpio_1_out[1];
        o_pad_oe[C_PAD_PIN_23]  = i_gpio_1_oe[1];
        o_pad_ie[C_PAD_PIN_23]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_23] = i_pwm[0];
        o_pad_oe[C_PAD_PIN_23]  = 1'b1;
      end
      C_SEL_B10: begin
        o_pad_ie[C_PAD_PIN_23]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_23]  = 1'b0;
      end
    endcase

    // ---- PIN24: GPIO1_0 / PWM_1 / SPID_CSB ----------------------------------
    case (w_sel_pin_24)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_24] = i_gpio_1_out[0];
        o_pad_oe[C_PAD_PIN_24]  = i_gpio_1_oe[0];
        o_pad_ie[C_PAD_PIN_24]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_24] = i_pwm[1];
        o_pad_oe[C_PAD_PIN_24]  = 1'b1;
      end
      C_SEL_B10: begin
        o_pad_ie[C_PAD_PIN_24]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_24]  = 1'b0;
      end
    endcase

    // ---- PIN25: GPIO2_7 / PWM_2 / SPID_MOSI ---------------------------------
    case (w_sel_pin_25)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_25] = i_gpio_2_out[7];
        o_pad_oe[C_PAD_PIN_25]  = i_gpio_2_oe[7];
        o_pad_ie[C_PAD_PIN_25]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_25] = i_pwm[2];
        o_pad_oe[C_PAD_PIN_25]  = 1'b1;
      end
      C_SEL_B10: begin
        o_pad_ie[C_PAD_PIN_25]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_25]  = 1'b0;
      end
    endcase

    // ---- PIN26: GPIO2_6 / PWM_3 / SPID_MISO ---------------------------------
    case (w_sel_pin_26)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_26] = i_gpio_2_out[6];
        o_pad_oe[C_PAD_PIN_26]  = i_gpio_2_oe[6];
        o_pad_ie[C_PAD_PIN_26]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_26] = i_pwm[3];
        o_pad_oe[C_PAD_PIN_26]  = 1'b1;
      end
      C_SEL_B10: begin
        o_pad_out[C_PAD_PIN_26] = i_spid_miso;
        o_pad_oe[C_PAD_PIN_26]  = i_spid_miso_oe;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_26]  = 1'b0;
      end
    endcase

    // ---- PIN29: GPIO2_5 / PWM_4 ---------------------------------------------
    case (w_sel_pin_29)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_29] = i_gpio_2_out[5];
        o_pad_oe[C_PAD_PIN_29]  = i_gpio_2_oe[5];
        o_pad_ie[C_PAD_PIN_29]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_29] = i_pwm[4];
        o_pad_oe[C_PAD_PIN_29]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_29]  = 1'b0;
      end
    endcase

    // ---- PIN30: GPIO2_4 / PWM_5 ---------------------------------------------
    case (w_sel_pin_30)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_30] = i_gpio_2_out[4];
        o_pad_oe[C_PAD_PIN_30]  = i_gpio_2_oe[4];
        o_pad_ie[C_PAD_PIN_30]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_30] = i_pwm[5];
        o_pad_oe[C_PAD_PIN_30]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_30]  = 1'b0;
      end
    endcase

    // ---- PIN31: GPIO2_3 / PWM_6 ---------------------------------------------
    case (w_sel_pin_31)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_31] = i_gpio_2_out[3];
        o_pad_oe[C_PAD_PIN_31]  = i_gpio_2_oe[3];
        o_pad_ie[C_PAD_PIN_31]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_31] = i_pwm[6];
        o_pad_oe[C_PAD_PIN_31]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_31]  = 1'b0;
      end
    endcase

    // ---- PIN32: GPIO2_2 / PWM_7 ---------------------------------------------
    case (w_sel_pin_32)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_32] = i_gpio_2_out[2];
        o_pad_oe[C_PAD_PIN_32]  = i_gpio_2_oe[2];
        o_pad_ie[C_PAD_PIN_32]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_32] = i_pwm[7];
        o_pad_oe[C_PAD_PIN_32]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_32]  = 1'b0;
      end
    endcase

    // ---- PIN33: TIM_EXT0 / GPIO0_2 ------------------------------------------
    case (w_sel_pin_33)
      C_SEL_B00: begin
        o_pad_ie[C_PAD_PIN_33]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_33] = i_gpio_0_out[2];
        o_pad_oe[C_PAD_PIN_33]  = i_gpio_0_oe[2];
        o_pad_ie[C_PAD_PIN_33]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_33]  = 1'b0;
      end
    endcase

    // ---- PIN34: TIM_EXT1 / GPIO0_1 ------------------------------------------
    case (w_sel_pin_34)
      C_SEL_B00: begin
        o_pad_ie[C_PAD_PIN_34]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_out[C_PAD_PIN_34] = i_gpio_0_out[1];
        o_pad_oe[C_PAD_PIN_34]  = i_gpio_0_oe[1];
        o_pad_ie[C_PAD_PIN_34]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_34]  = 1'b0;
      end
    endcase

    // ---- PIN38: GPIO2_1 / TIM_EXT2 ------------------------------------------
    case (w_sel_pin_38)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_38] = i_gpio_2_out[1];
        o_pad_oe[C_PAD_PIN_38]  = i_gpio_2_oe[1];
        o_pad_ie[C_PAD_PIN_38]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_ie[C_PAD_PIN_38]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_38]  = 1'b0;
      end
    endcase

    // ---- PIN39: GPIO2_0 / TIM_EXT3 ------------------------------------------
    case (w_sel_pin_39)
      C_SEL_B00: begin
        o_pad_out[C_PAD_PIN_39] = i_gpio_2_out[0];
        o_pad_oe[C_PAD_PIN_39]  = i_gpio_2_oe[0];
        o_pad_ie[C_PAD_PIN_39]  = 1'b1;
      end
      C_SEL_B01: begin
        o_pad_ie[C_PAD_PIN_39]  = 1'b1;
      end
      default: begin
        o_pad_oe[C_PAD_PIN_39]  = 1'b0;
      end
    endcase

    // ---- PIN40: GPIO0_0, fixed ----------------------------------------------
    o_pad_out[C_PAD_PIN_40] = i_gpio_0_out[0];
    o_pad_oe[C_PAD_PIN_40]  = i_gpio_0_oe[0];
    o_pad_ie[C_PAD_PIN_40]  = 1'b1;
  end

  // IP inputs: each IP input is placed on one pad. It takes that pad's Y while
  // the pad's field selects it, and its idle value otherwise, so an IP whose
  // pad is on another function sees a quiet line (header, "Idle value").
  always_comb begin : p_com_ip_in
    // idle values
    o_gpio_0_in   = '0;
    o_gpio_1_in   = '0;
    o_gpio_2_in   = '0;
    o_uart_0_rx   = 1'b1;
    o_uart_1_rx   = 1'b1;
    o_spih_sd     = '0;
    o_spid_sck    = 1'b0;
    o_spid_csb    = 1'b1;
    o_spid_mosi   = 1'b0;
    o_i2c_scl     = 1'b1;
    o_i2c_sda     = 1'b1;
    o_tim_ext     = '0;

    // ---- JTAG, fixed pads ----------------------------------------------------
    o_jtag_tck    = i_pad_in[C_PAD_PIN_5];
    o_jtag_tms    = i_pad_in[C_PAD_PIN_6];
    o_jtag_tdi    = i_pad_in[C_PAD_PIN_7];
    o_jtag_trst_n = i_pad_in[C_PAD_PIN_9];

    // ---- GPIO 0: PIN10, 11 b01, PIN12 fixed, PIN21, 22, 33, 34 b01, PIN40 ----
    if (w_sel_pin_10 == C_SEL_B01)
      o_gpio_0_in[7] = i_pad_in[C_PAD_PIN_10];
    if (w_sel_pin_11 == C_SEL_B01)
      o_gpio_0_in[6] = i_pad_in[C_PAD_PIN_11];
    o_gpio_0_in[5] = i_pad_in[C_PAD_PIN_12];
    if (w_sel_pin_21 == C_SEL_B01)
      o_gpio_0_in[4] = i_pad_in[C_PAD_PIN_21];
    if (w_sel_pin_22 == C_SEL_B01)
      o_gpio_0_in[3] = i_pad_in[C_PAD_PIN_22];
    if (w_sel_pin_33 == C_SEL_B01)
      o_gpio_0_in[2] = i_pad_in[C_PAD_PIN_33];
    if (w_sel_pin_34 == C_SEL_B01)
      o_gpio_0_in[1] = i_pad_in[C_PAD_PIN_34];
    o_gpio_0_in[0] = i_pad_in[C_PAD_PIN_40];

    // ---- GPIO 1: PIN15-20, 23, 24 b00 ----------------------------------------
    if (w_sel_pin_15 == C_SEL_B00)
      o_gpio_1_in[7] = i_pad_in[C_PAD_PIN_15];
    if (w_sel_pin_16 == C_SEL_B00)
      o_gpio_1_in[6] = i_pad_in[C_PAD_PIN_16];
    if (w_sel_pin_17 == C_SEL_B00)
      o_gpio_1_in[5] = i_pad_in[C_PAD_PIN_17];
    if (w_sel_pin_18 == C_SEL_B00)
      o_gpio_1_in[4] = i_pad_in[C_PAD_PIN_18];
    if (w_sel_pin_19 == C_SEL_B00)
      o_gpio_1_in[3] = i_pad_in[C_PAD_PIN_19];
    if (w_sel_pin_20 == C_SEL_B00)
      o_gpio_1_in[2] = i_pad_in[C_PAD_PIN_20];
    if (w_sel_pin_23 == C_SEL_B00)
      o_gpio_1_in[1] = i_pad_in[C_PAD_PIN_23];
    if (w_sel_pin_24 == C_SEL_B00)
      o_gpio_1_in[0] = i_pad_in[C_PAD_PIN_24];

    // ---- GPIO 2: PIN25, 26, 29-32, 38, 39 b00 --------------------------------
    if (w_sel_pin_25 == C_SEL_B00)
      o_gpio_2_in[7] = i_pad_in[C_PAD_PIN_25];
    if (w_sel_pin_26 == C_SEL_B00)
      o_gpio_2_in[6] = i_pad_in[C_PAD_PIN_26];
    if (w_sel_pin_29 == C_SEL_B00)
      o_gpio_2_in[5] = i_pad_in[C_PAD_PIN_29];
    if (w_sel_pin_30 == C_SEL_B00)
      o_gpio_2_in[4] = i_pad_in[C_PAD_PIN_30];
    if (w_sel_pin_31 == C_SEL_B00)
      o_gpio_2_in[3] = i_pad_in[C_PAD_PIN_31];
    if (w_sel_pin_32 == C_SEL_B00)
      o_gpio_2_in[2] = i_pad_in[C_PAD_PIN_32];
    if (w_sel_pin_38 == C_SEL_B00)
      o_gpio_2_in[1] = i_pad_in[C_PAD_PIN_38];
    if (w_sel_pin_39 == C_SEL_B00)
      o_gpio_2_in[0] = i_pad_in[C_PAD_PIN_39];

    // ---- UART RX: UART0 PIN11 b00, UART1 PIN20 b01 ---------------------------
    if (w_sel_pin_11 == C_SEL_B00)
      o_uart_0_rx = i_pad_in[C_PAD_PIN_11];
    if (w_sel_pin_20 == C_SEL_B01)
      o_uart_1_rx = i_pad_in[C_PAD_PIN_20];

    // ---- SPI host SD: PIN17, 18 b01 ------------------------------------------
    if (w_sel_pin_17 == C_SEL_B01)
      o_spih_sd[0] = i_pad_in[C_PAD_PIN_17];
    if (w_sel_pin_18 == C_SEL_B01)
      o_spih_sd[1] = i_pad_in[C_PAD_PIN_18];

    // ---- SPI device: PIN23-25 b10 --------------------------------------------
    if (w_sel_pin_23 == C_SEL_B10)
      o_spid_sck = i_pad_in[C_PAD_PIN_23];
    if (w_sel_pin_24 == C_SEL_B10)
      o_spid_csb = i_pad_in[C_PAD_PIN_24];
    if (w_sel_pin_25 == C_SEL_B10)
      o_spid_mosi = i_pad_in[C_PAD_PIN_25];

    // ---- I2C: PIN21, 22 b00 --------------------------------------------------
    if (w_sel_pin_21 == C_SEL_B00)
      o_i2c_scl = i_pad_in[C_PAD_PIN_21];
    if (w_sel_pin_22 == C_SEL_B00)
      o_i2c_sda = i_pad_in[C_PAD_PIN_22];

    // ---- TIM_EXT: PIN33, 34 b00, PIN38, 39 b01 -------------------------------
    if (w_sel_pin_33 == C_SEL_B00)
      o_tim_ext[0] = i_pad_in[C_PAD_PIN_33];
    if (w_sel_pin_34 == C_SEL_B00)
      o_tim_ext[1] = i_pad_in[C_PAD_PIN_34];
    if (w_sel_pin_38 == C_SEL_B01)
      o_tim_ext[2] = i_pad_in[C_PAD_PIN_38];
    if (w_sel_pin_39 == C_SEL_B01)
      o_tim_ext[3] = i_pad_in[C_PAD_PIN_39];
  end

endmodule
