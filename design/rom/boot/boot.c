/*
 * QSOC boot ROM -- serial bootloader.
 *
 * Receives one frame over UART0 (polling, no interrupt), writes the payload
 * into ISRAM word by word, checks both CRCs and jumps to ENTRY
 * (QNSC_BOOT_SPEC V3.1, 7). Nothing is sent after reset: the ROM listens for
 * the magic at once. Every step after the magic answers the PC loader with a
 * 4-byte token (boot.h); on any failure the ROM sends the token, drains the
 * line, sends QRDY and waits for the PC to resend the whole frame.
 *
 * Constraints that shape the code:
 *  - ROM budget 1 KiB of code (Day005). Bitwise CRC32, no lookup table.
 *  - No .data / .bss (link.ld asserts it): state lives in registers + stack.
 *  - No .rodata: tokens are 32-bit immediates, not strings.
 *  - One 32-bit write per 4 received bytes keeps the payload loop simple
 *    (QNSC_BOOT_SPEC 7.4); ISRAM itself also takes byte writes.
 */
#include <stdint.h>
#include "boot.h"

#define REG32(addr) (*(volatile uint32_t *)(addr))
#define UART(off)   REG32(UART0_BASE + (off))

#define RX_TMO   (-1)
#define RX_ERR   (-2)

static void uart_init(void)
{
    UART(UART_LCR) = LCR_DLAB;
    UART(UART_DLL) = UART_DIVISOR & 0xFFu;
    UART(UART_DLM) = UART_DIVISOR >> 8;
    UART(UART_LCR) = LCR_8N1;          /* DLAB back to 0 */
    UART(UART_FCR) = FCR_EN_CLR;
    UART(UART_IER) = 0;                /* polling only   */
}

static void uart_putc(uint32_t c)
{
    while ((UART(UART_LSR) & LSR_THRE) == 0) { }
    UART(UART_THR) = c & 0xFFu;
}

/* Wait until the last byte has left the shift register. */
static void uart_tx_flush(void)
{
    while ((UART(UART_LSR) & LSR_TEMT) == 0) { }
}

/* Send a token: 4 bytes, least significant first. */
static void put_tok(uint32_t tok)
{
    for (int i = 0; i < 4; i++) {
        uart_putc(tok);
        tok >>= 8;
    }
}

/* One byte. limit == 0 waits forever (used only while hunting the magic). */
static int uart_getc(uint32_t limit)
{
    uint32_t n = 0;
    for (;;) {
        uint32_t lsr = UART(UART_LSR);
        if (lsr & LSR_ERR)
            return RX_ERR;
        if (lsr & LSR_DR)
            return (int)(UART(UART_RBR) & 0xFFu);
        if (limit != 0 && ++n == limit)
            return RX_TMO;
    }
}

/* Four bytes, little-endian. Returns 0 or a failure token. */
static uint32_t get32(uint32_t *out)
{
    uint32_t w = 0;
    for (int i = 0; i < 4; i++) {
        int c = uart_getc(RX_TIMEOUT);
        if (c == RX_TMO) return TOK_FTMO;
        if (c == RX_ERR) return TOK_FUAR;
        w = (w >> 8) | ((uint32_t)c << 24);
    }
    *out = w;
    return 0;
}

/* CRC32 (zlib), bitwise, one word = its 4 bytes in little-endian order. */
static uint32_t crc32_word(uint32_t crc, uint32_t w)
{
    crc ^= w;
    for (int i = 0; i < 32; i++)
        crc = (crc >> 1) ^ (0xEDB88320u & (0u - (crc & 1u)));
    return crc;
}

/* Throw away whatever the PC was still sending, until the line is quiet.
 * Clears the RX FIFO only: the TX side may still hold the failure token. */
static void uart_drain(void)
{
    UART(UART_FCR) = FCR_EN_CLR_RX;
    while (uart_getc(DRAIN_IDLE) != RX_TMO) { }
}

/* One download attempt. Returns only on failure, with the token to send. */
static uint32_t boot_once(void)
{
    uint32_t w, len, load, entry, crc, rc;

    /* Hunt the magic through a 4-byte sliding window, with no time limit.
     * Noise on the line (cable plugged in, terminal opened) is skipped
     * without a reply, and so is a byte with a UART error: reading LSR
     * cleared the error, reading RBR drops the byte (QNSC_BOOT_SPEC 7.1). */
    w = 0;
    do {
        int c = uart_getc(0);
        if (c == RX_ERR) {
            (void)UART(UART_RBR);
            continue;
        }
        w = (w >> 8) | ((uint32_t)c << 24);
    } while (w != MAGIC_QSOC);

    /* ---- Header ---------------------------------------------------- */
    crc = crc32_word(0xFFFFFFFFu, w);
    if ((rc = get32(&len)))   return rc;
    crc = crc32_word(crc, len);
    if ((rc = get32(&load)))  return rc;
    crc = crc32_word(crc, load);
    if ((rc = get32(&entry))) return rc;
    crc = crc32_word(crc, entry);
    if ((rc = get32(&w)))     return rc;
    if ((crc ^ 0xFFFFFFFFu) != w)
        return TOK_FHCR;

    if (len == 0 || (len & 3u) || len > APP_MAX_LEN)            return TOK_FHDR;
    if ((load & 3u) || load < ISRAM_APP_BASE || load > ISRAM_END) return TOK_FHDR;
    if (len > ISRAM_END - load)                                  return TOK_FHDR;
    if ((entry & 1u) || entry < load || entry - load >= len)     return TOK_FHDR;

    put_tok(TOK_ACKH);

    /* ---- Payload: one AXI word write per 4 bytes, CRC as it arrives -- */
    crc = 0xFFFFFFFFu;
    for (uint32_t a = load; a != load + len; a += 4) {
        if ((rc = get32(&w))) return rc;
        REG32(a) = w;
        crc = crc32_word(crc, w);
    }
    if ((rc = get32(&w))) return rc;
    if ((crc ^ 0xFFFFFFFFu) != w)
        return TOK_FPCR;

    /* ---- Jump: ACK must be fully on the wire before the app may
     *      reprogram UART0.                                              */
    put_tok(TOK_ACKP);
    uart_tx_flush();
    /* fence.i (Zifencei, in -march; QNSC_BOOT_SPEC 7.5, 8). Ibex flushes
     * its prefetch buffer on it, so no stale ROM-era fetch survives the
     * jump.                                                              */
    __asm__ volatile ("fence.i" ::: "memory");
    ((void (*)(void))entry)();
    for (;;) { }                       /* the app never returns */
}

void boot_main(void)
{
    uart_init();
    for (;;) {
        put_tok(boot_once());          /* the failure token, sent in full */
        uart_tx_flush();
        uart_drain();
        put_tok(TOK_QRDY);             /* the PC may resend the frame     */
    }
}
