/*
 * QSOC boot ROM -- constants shared by crt0.S and boot.c.
 *
 * Every value here is also used by tools/qsoc_image.py and tools/rom_model.py.
 * Change one, change all three (tools/test_protocol.py catches a mismatch in
 * the Python side only).
 */
#ifndef QSOC_BOOT_H
#define QSOC_BOOT_H

/* ---- Memory map (util/qsoc_contract.yml, QNSC_BOOT_SPEC V3.1 Table 3-1) -
 * TODO(lead): take these from the qnsc_map.h generated from the contract
 * (BOOT_SPEC Table 10-1), so the C side cannot drift from the RTL side.
 */
#define ROM_BASE        0x00000000u   /* 2 KiB, AXI_M0                       */
#define ISRAM_BASE      0x20000000u   /* 64 KiB, AXI_M1                      */
#define ISRAM_APP_BASE  0x20001000u   /* first 4 KiB = debug window, skip it */
#define ISRAM_END       0x20010000u   /* one past the last byte              */
#define DSRAM_BASE      0x30000000u   /* 32 KiB, AXI_M2                      */
#define DSRAM_END       0x30008000u   /* stack grows down from here          */

#define APP_MAX_LEN     (ISRAM_END - ISRAM_APP_BASE)   /* 61440 bytes */

/* ---- UART0 (pulp apb_uart wrapping obi_uart, 16550-compatible) --------
 * apb_uart forwards {PADDR[2:0], 2'b00}: register n sits at byte offset 4*n.
 * Confirmed from the apb_uart RTL: PADDR = i_bus_apb_paddr[4:2].
 */
#define UART0_BASE      0x80020000u   /* APB_M8 (0x8002_4000 is UART1)       */
#define UART_RBR        0x00u         /* read : receive buffer  (DLAB=0)     */
#define UART_THR        0x00u         /* write: transmit holding (DLAB=0)    */
#define UART_DLL        0x00u         /* divisor low            (DLAB=1)     */
#define UART_IER        0x04u         /* interrupt enable       (DLAB=0)     */
#define UART_DLM        0x04u         /* divisor high           (DLAB=1)     */
#define UART_FCR        0x08u         /* FIFO control (write)                */
#define UART_LCR        0x0Cu         /* line control                        */
#define UART_LSR        0x14u         /* line status                         */

#define LCR_DLAB        0x80u
#define LCR_8N1         0x03u
#define FCR_EN_CLR      0x07u         /* enable FIFOs, clear RX and TX       */
#define FCR_EN_CLR_RX   0x03u         /* enable FIFOs, clear RX only: a drain */
                                      /* must not drop a token still in TX   */
#define LSR_DR          0x01u         /* data ready                          */
#define LSR_ERR         0x0Eu         /* overrun | parity | framing          */
#define LSR_THRE        0x20u         /* THR empty: can queue the next byte  */
#define LSR_TEMT        0x40u         /* transmitter fully empty             */

/* 20 MHz / (16 x 65) = 19 231 baud, +0.16 % from 19 200 (QNSC_BOOT_SPEC 5):
 * the fastest standard rate within 0.5 % at 20 MHz (28 800 is +0.94 %,
 * 38 400 and up -1.36 %), inside the mentor's 10 000-20 000 range.        */
#define UART_DIVISOR    65u

/* ---- Timeouts (loop counts, not time; QNSC_BOOT_SPEC V3.1 7.3) ---------
 * A poll is at least one APB read and an APB transfer takes at least 2 clk,
 * so these are MINIMUM times at 20 MHz: RX_TIMEOUT >= 100 ms (192 bytes at
 * 19 231 baud), DRAIN_IDLE >= 50 ms (96 bytes). The margins cover gaps the
 * PC's operating system and USB-serial adapter put in the stream. A slower
 * poll only lengthens them, but RX_TIMEOUT must stay below the loader's 2 s
 * token wait, so a poll must take fewer than 40 clk. The real time per poll
 * is measured in simulation (QNSC_BOOT_SPEC 10).
 */
#define RX_TIMEOUT      1000000u      /* between two bytes of one frame      */
#define DRAIN_IDLE      500000u       /* line quiet this long = drained      */

/* ---- Frame format ------------------------------------------------------
 *  off  size  field      rule checked by ROM
 *  0x00  4    MAGIC      bytes 'Q','S','O','C' in that order
 *  0x04  4    LENGTH     payload bytes, %4 == 0, 4 .. APP_MAX_LEN
 *  0x08  4    LOAD_ADDR  %4 == 0, >= ISRAM_APP_BASE, LOAD+LENGTH <= ISRAM_END
 *  0x0C  4    ENTRY      %2 == 0, LOAD <= ENTRY < LOAD+LENGTH
 *  0x10  4    HDR_CRC    CRC32 of bytes 0x00..0x0F
 *  0x14  N    PAYLOAD    raw bytes, as in the app's .bin
 *  +N    4    PAY_CRC    CRC32 of PAYLOAD
 * All multi-byte fields little-endian (least significant byte sent first).
 * CRC32 = zlib/IEEE: reflected poly 0xEDB88320, init and final XOR 0xFFFFFFFF.
 */
#define TOK(a, b, c, d) ((unsigned)(a) | ((unsigned)(b) << 8) | \
                         ((unsigned)(c) << 16) | ((unsigned)(d) << 24))

#define MAGIC_QSOC      TOK('Q', 'S', 'O', 'C')   /* 0x434F5351 */

/* ---- Handshake tokens, ROM -> PC, always 4 ASCII bytes ----------------- */
#define TOK_QRDY        TOK('Q', 'R', 'D', 'Y')   /* drained after a failure: */
                                                  /* resend the whole frame   */
#define TOK_ACKH        TOK('A', 'C', 'K', 'H')   /* header accepted          */
#define TOK_ACKP        TOK('A', 'C', 'K', 'P')   /* payload ok, jumping      */
#define TOK_FHCR        TOK('F', 'H', 'C', 'R')   /* header CRC mismatch      */
#define TOK_FHDR        TOK('F', 'H', 'D', 'R')   /* header field out of range*/
#define TOK_FPCR        TOK('F', 'P', 'C', 'R')   /* payload CRC mismatch     */
#define TOK_FTMO        TOK('F', 'T', 'M', 'O')   /* gap between bytes too long*/
#define TOK_FUAR        TOK('F', 'U', 'A', 'R')   /* UART overrun/parity/frame*/

#endif /* QSOC_BOOT_H */
