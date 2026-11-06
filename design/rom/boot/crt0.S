/*
 * QSOC boot ROM -- startup.
 *
 * Ibex: first fetch at boot_addr_i + 0x80, mtvec resets to boot_addr_i in
 * vectored mode, so 0x00..0x7F is the 32-entry trap table (entry 31 = NMI).
 * A trap inside the ROM has no recovery path: park the core. WDT is off
 * after reset (HAS), so only a reset leaves this loop.
 */
    .section .vectors, "ax"
    .option push
    .option norvc              /* each entry must be exactly 4 bytes */
    .globl  _vectors
_vectors:
    .rept 32
    j       rom_trap
    .endr
    .option pop

    .section .text.start, "ax"
    .globl  _start
_start:                        /* = ROM_BASE + 0x80 */
    la      sp, _stack_top     /* top of DSRAM, see link.ld */
    call    boot_main
rom_trap:
    j       rom_trap
