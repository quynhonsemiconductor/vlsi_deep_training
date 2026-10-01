/*
 * QSOC boot ROM linker script.
 * ROM 2 KiB at 0x0000_0000: 0x000-0x07F trap table, 0x080-0x7FF code.
 * Stack at the top of DSRAM; the ROM owns no RAM variables at all.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    ROM (rx) : ORIGIN = 0x00000000, LENGTH = 2K
}

_stack_top = 0x30008000;       /* DSRAM_END */

SECTIONS
{
    .vectors 0x00000000 : { KEEP(*(.vectors)) } > ROM
    .text    0x00000080 : {
        KEEP(*(.text.start))
        *(.text .text.*)
        *(.rodata .rodata.* .srodata .srodata.*)
    } > ROM
    _rom_end = .;

    .data : { *(.data .data.* .sdata .sdata.*) } > ROM
    .bss  : { *(.bss .bss.* .sbss .sbss.* COMMON) } > ROM

    /DISCARD/ : { *(.comment) *(.riscv.attributes) *(.note*) *(.eh_frame*) }
}

ASSERT(SIZEOF(.vectors) == 0x80, "trap table must be exactly 128 bytes")
ASSERT(SIZEOF(.data) == 0 && SIZEOF(.bss) == 0,
       "boot ROM must not use .data/.bss: nothing initialises RAM for it")
ASSERT(_rom_end <= 0x800, "boot ROM does not fit in 2 KiB")
