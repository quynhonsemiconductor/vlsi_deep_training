# QNSC_BOOT — design decisions and record

**This is not the specification.** That is [`QNSC_BOOT_SPEC.md`](QNSC_BOOT_SPEC.md).

This file holds why V3.0 differs from V2.2, and the V2.2 document by Nguyen Hao
Nam, kept whole below. Its figures are not reproduced: they were in colour and are
replaced by the figures of the specification.

---

# 1. V2.2 to V3.0

The protocol, frame and bootloader are V2.2's.

| Change | Why |
|---|---|
| `UART0` base `0x8002_4000`, "APB slave 9" corrected to `0x8002_0000`, `APB_M8`; the memory-map table generated from the contract | `0x8002_4000` is `UART1` since `GPIO3` was dropped. The value came from HAS v4. A bootloader built with it would never hear the PC |
| `qnsc_map.h` generated from the contract, required of the lead; `boot.h` takes addresses from it | The same rule as `qnsc_pkg.sv`, so the C side cannot drift from the RTL side |
| Byte time 86.8 µs / 1736 cycles corrected to 88.0 µs / 1760; download 5.3 s to 5.4 s | V2.2 used 115 200 baud; the divisor gives 113 636 |
| "The SRAM controller has no byte-strobe path, so single bytes would overwrite three" removed | `QNSC_RAM_MAS` V2.2 added the strobe FIFO; byte writes are correct. Word writes are kept because they are four times fewer bus transfers |
| `fence.i` as `.word 0x0000100F` replaced by `-march=rv32imc_zicsr_zifencei` | The mnemonic is rejected only because Zifencei is not in `-march`; naming the extension is the documented fix |
| Reset and power-up steps, debug-entry table and rules cut to references | Owned by `QNSC_SCRC_MAS` 7.3, 7.5 and `QNSC_SYSDBG_MAS` 7.1; three copies had already drifted once (V2.2 guard fix) |
| "16 cycles" removed from the reset stage | `SCRC` may drop the stretch after POR (`QNSC_SCRC_DECISIONS` 4); this document does not depend on it |
| Code budget, CRC choice, section limits, `sp`, source files moved here from the ROM | They are bootloader content, not ROM hardware |
| Watchdog "disabled after reset" backed by `aon_timer` `WDOG_CTRL` reset value 0 | Read in `aon_timer_reg_top.sv` |
| RX FIFO 16 bytes and the 16550 offsets checked in `obi_uart_rx.sv` and `obi_uart_pkg.sv` (branch `feat/uart-apb-wrapper`) | V2.2 stated them without a source |
| "Why polling" reduced to the design itself; reasons kept below | Reason 1 ("the interrupt map is still being revised") is no longer true: INTMAP V2.3 is fixed |
| Verification: V2.2 `BOOT_001` (first fetch after release) and `BOOT_010` (debug boot) removed; header failures merged | Duplicates of `SCRC_RST_003`, `ROM_003` and `SCRC_DBG_001`; `FHCR` and `FHDR` are one check of one step |
| `SYSCSR` removed from the boot memory map; UART-wrapper requirement removed | The bootloader never accesses `SYSCSR`; register *n* at 4 x *n* is a property of `obi_uart` (`RegAlignBytes` = 4), not a request |
| PC-tools prose merged into the source table; `-Os` and the "guards before CPU" review row removed | Said twice; `-Os` is unverifiable until the source exists; the guard fix is `QNSC_SCRC_MAS` Appendix B |
| `FCR`, `LCR`, `LSR` bits checked in `obi_uart_pkg.sv` | `fcr_bits_t`, `lcr_bits_t`, `lsr_bits_t` match the table |

## Why polling

1. It fits the 1 KiB budget: no handler, no register save, no buffer shared with a
   handler.
2. The CPU has nothing else to do during boot.
3. It is fast enough: a byte arrives every 1760 cycles, handling it takes 100--300,
   and the 16-byte RX FIFO absorbs any delay.
4. It is easy to follow in simulation and on FPGA.

The Day006 minutes mention both an interrupt-driven receive and the ROM "watching
the UART status"; the ROM owner chose polling. The application may use UART
interrupts after the jump.

## Why `LOAD_ADDR` and `ENTRY` are separate

The first byte of the image is the vector table, not the first instruction. With
one field the ROM would have to assume either `ENTRY` = `LOAD` (no vector table at
the start of the image) or `ENTRY` = `LOAD` + `0x80` (a convention fixed in the ROM
forever). With `ENTRY` from the linker the image describes itself, for 4 header
bytes and three comparisons.

---

# V2.2 as issued

## Reversion and History

| Version | Date (mm/dd/yyyy) | Author | Reviewer | Description of Change |
|:---|:---|:---|:---|:---|
| V1.0 | 09/17/2026 | Nguyen Hao Nam | \- | Initial boot flow: UART download into SRAM, single-shot frame with CRC32. |
| V1.1 | 09/21/2026 | Nguyen Hao Nam | Nguyen Hung Quan | Main FSM replaced by the MRV-CPU program; three reset sources. |
| V1.2 | 09/21/2026 | Nguyen Hao Nam | Huynh Phuoc Truong Sinh | Reset vector ROM base + 0x80; rewritten in English. |
| V2.0 | 09/24/2026 | Nguyen Hao Nam | \- | Rewritten on the QNSC document template to match Booting_Flow_Diagram_v2 and the bootloader source: all domains released together and the CPU last; debug entry via o_cpu_hold; MAGIC 'QSOC', 20-byte header with HDR_CRC, PAY_CRC; mandatory 4-byte token handshake with PC-driven retry; inter-byte timeout; UART0 polling configuration; memory map from the SoC contract; application contract. |
| V2.1 | 09/24/2026 | Nguyen Hao Nam | \- | Open issues closed: debug boot per SYSDBG MAS V3.0 (DBG_EN capture, CPUHOLD, boot address 0x2000_1000, first instruction 0x2000_1080); UART register mapping from the apb_uart RTL; timeouts defined as minimums with the loader margins; polling decision recorded; code-size limits enforced by the build; figures translated to English. |
| V2.2 | 09/24/2026 | Nguyen Hao Nam | \- | Power-up order fixed to match SCRC V2.3: the APB guards are opened before the CPU is released, so the first UART0 access of the boot ROM cannot receive PSLVERR; Figure 4-1 and Table 4-1 updated. |


## Overview

QSOC has no Flash, so no program survives power-off. After every reset the application is downloaded from a PC into instruction RAM (ISRAM) over UART0 by the bootloader in the boot ROM, and then started. This document specifies that flow from the reset source to the first instruction of the application: the SCRC reset and release sequence, the ROM bootloader, the image format, the PC–ROM handshake and the contract the application must follow.

Related specifications: SCRC (clock/reset sequencing, V2.3), ROM (boot memory hardware, V2.1), SYSCSR (reset cause). The bootloader source, the PC tools and a Python model of the protocol are in repo implement/vlsi_deep_training/design/rom/boot/; boot.h there is the single source of truth for every constant in this document.

## Feature

- Same boot flow after every reset (POR, watchdog, software reset).

- SCRC releases every domain together, opens the APB guards, and releases the CPU last; Ibex starts at ROM base + 0x80.

- Debug boot: with the DBG_EN pin set, SYSDBG holds the CPU in reset while the host loads the image over JTAG; the CPU then starts at 0x2000_1080 without running the ROM.

- UART0 download at 115200 baud, 8N1, polling (no interrupt).

- Frame = 20-byte header (MAGIC 'QSOC', LENGTH, LOAD_ADDR, ENTRY, HDR_CRC) + payload + PAY_CRC; all fields little-endian; CRC32 (zlib/IEEE).

- Mandatory handshake: every step answers the PC with a 4-byte ASCII token (QRDY, ACKH, ACKP, or a failure token).

- Header checked before any RAM write; payload written to ISRAM one 32-bit word at a time.

- Retry driven by the PC: on any failure the ROM drains the line, sends QRDY again and the PC resends the whole frame.

- The application may be up to 60 KiB (0x2000_1000 – 0x2000_FFFF); the first 4 KiB of ISRAM are kept for debug.

## Block Diagram

The download path is PC → USB-UART cable → UART0 (P_BUS APB slave 9, 0x8002_4000) → Ibex → S_BUS → ISRAM (AXI_M1). The bootloader runs from ROM (AXI_M0) with its stack in DSRAM (AXI_M2).

*[Figure 3‑1. QSOC system — blocks used during boot: CPU, ROM, SRAM, S_BUS, AXI2APB, P_BUS, UART0, SCRC -- not reproduced]*

| Region | Address | Size | Use during boot |
|:---|:---|:---|:---|
| ROM | 0x0000_0000 – 0x0000_07FF | 2 KiB | Bootloader code; vectors at 0x000, \_start at 0x080. |
| ISRAM debug window | 0x2000_0000 – 0x2000_0FFF | 4 KiB | Reserved for the debug stub; never written by the bootloader. |
| ISRAM application | 0x2000_1000 – 0x2000_FFFF | 60 KiB | Downloaded application (LOAD_ADDR ≥ 0x2000_1000). |
| DSRAM | 0x3000_0000 – 0x3000_7FFF | 32 KiB | Bootloader stack, from 0x3000_8000 downward. |
| SCRC | 0x8000_0000 | 16 KiB | Not used by the bootloader. |
| SYSCSR | 0x8000_4000 | 16 KiB | RESET_CAUSE (read by the application). |
| UART0 | 0x8002_4000 | 16 KiB | Download channel. |

Table 3‑1. Memory map used by the boot flow

## Boot Sequence

Figure 4-1 shows the flow from the reset source to the first instruction fetch; the bootloader part is shown in Figure 6-1. Both figures are taken from the design diagram Booting_Flow_Diagram_v2.drawio.

*[Figure 4‑1. Reset, power-up and CPU start -- not reproduced]*

| Stage | Done by | What happens | Ends when |
|:---|:---|:---|:---|
| 1\. Reset | SCRC (RRC) | POR, WDT bite or SW_RST: o_sys_rst_n held low for 16 cycles; every domain reset asserted; cause recorded in SYSCSR. | o_sys_rst_n releases. |
| 2\. Power-up | SCRC (MRV-CPU) | Clocks enabled from CLK_EN (all except TIMER1), wait 3 cycles, all domains except the CPU released, wait 16 cycles, APB guards opened (APB_BLK ← ~CLK_EN), CPU released. | RST_REL\[CPU\] = 1. |
| 3\. Mode | SYSDBG | DBG_EN captured once after POR. 0: o_cpu_hold falls after 3 cycles. 1: o_cpu_hold stays 1 until the host clears CPUHOLD (Section 5). | o_cpu_hold = 0. |
| 4\. ROM start | Ibex | First fetch at 0x0000_0080; sp = 0x3000_8000; call boot_main. | UART0 configured. |
| 5\. Download | ROM bootloader | QRDY, header, ACKH, payload into ISRAM, PAY_CRC, ACKP; retry on failure. | Frame accepted. |
| 6\. Jump | ROM bootloader | Wait until ACKP has left UART0, fence.i, jump to ENTRY. | Application running. |

Table 4‑1. Boot stages

### Reset and Power-up (SCRC)

The three reset sources — power-on reset, watchdog bite and software reset (SW_RST) — all go through the Reset Request Controller in SCRC, which latches the request, holds the system reset for 16 cycles and records the cause in SYSCSR RESET_CAUSE. There is no external reset pin and no debug reset.

When the system reset releases, MRV-CPU runs the power-up program from its CRM ROM:

1.  ICG_EN ← CLK_EN: every peripheral clock starts except TIMER1; the always-on clocks (CPU, buses, ROM, RAM, SYSDBG) are never gated.

2.  Wait at least 3 cycles so the enabled clocks reach the reset synchronizers. No other clock wait is needed: there is no PLL, and the power-on reset lasts longer than the oscillator start-up.

3.  Release every domain except the CPU at the same time: ROM, RAM, S_BUS, P_BUS and the peripherals.

4.  Wait 16 cycles.

5.  Open the APB guards of every running peripheral (APB_BLK ← ~CLK_EN; TIMER1 stays blocked).

6.  Release the CPU. Ibex needs 2 more cycles before its first instruction request.

The release order is held in the CRM ROM program, so it can be changed without an RTL change. Releasing all domains together follows the mentor's decision of 24/09: there is no known reason to release ROM or RAM earlier, and the only requirement is that the CPU starts after its buses and memories. The guards are opened before the CPU is released because the boot ROM writes UART0 within its first instructions: with the guard still closed that write would receive PSLVERR and the ROM would stop in its trap handler. Details are in the SCRC specification, Section 7.

### CPU Start

Ibex fetches its first instruction from {boot_addr_i\[31:8\], 8'h80}. With boot_addr_i tied to the ROM base this is 0x0000_0080. The 128 bytes below it hold the trap vector table, because mtvec resets to boot_addr_i in vectored mode. The startup code (crt0.S) sets sp to 0x3000_8000 (top of DSRAM) and calls boot_main. A trap inside the ROM jumps to a parking loop; only a reset leaves it.

## Debug Entry

The debug entry is specified by SYSDBG (QNSC_SYSDBG_MAS V3.0, sections 7.1–7.2); this section summarises what the boot flow depends on. One external pin, DBG_EN, decides who starts the CPU after power-on. SYSDBG synchronises it and captures it **once**, three cycles after its power-on reset releases; the captured value o_dbg_en holds until the next power-on reset, so toggling the pin later changes nothing.

|  | DBG_EN = 0 — normal boot | DBG_EN = 1 — debug boot |
|:---|:---|:---|
| CPU leaves reset | When SCRC releases it (o_cpu_hold is 0 three cycles after POR) | When SCRC releases it **and** the host writes CPUHOLD = 0 |
| Ibex boot_addr_i | 0x0000_0000 (ROM) | 0x2000_1000 (ISRAM) |
| First instruction | 0x0000_0080 — the bootloader of Section 6 | 0x2000_1080 — the image loaded by the host |
| Image source | UART0 download (Section 6) | JTAG: debug window 0x2000_0000–0x0FFF, then the image from 0x2000_1000 |

Table 5‑1. Normal boot and debug boot

In debug boot the host powers the chip on, writes the debug window and the program image through SYSDBG while the CPU is held, optionally requests a halt before the first instruction, and writes CPUHOLD = 0. Writing CPUHOLD = 1 puts the CPU back in reset with ISRAM untouched, so a new image can be loaded without a power cycle. To debug the ROM bootloader itself, the host halts the core before its first instruction and sets dpc = 0x0000_0080.

- o_cpu_hold only holds the CPU; it is not a reset source and sets no RESET_CAUSE bit. SYSDBG is reset by POR only, so the captured mode and the hold survive watchdog and software resets.

- The ISRAM array has no reset (RAM MAS V2.1), so a loaded image survives a watchdog or software reset.

- The 4 KiB debug window is written by the host for a debug session only; it is never part of the production image.

- The watchdog keeps running during a halt and Ibex ignores its NMI in Debug Mode, so firmware (or the host) disables the watchdog before a debug session.

- DBG_EN needs an input pad with a board pull-down; the pad is assigned by the pad owner (it may share a pad whose IO MUX default is an input, because it is sampled only after power-on).

The application layout of Section 8 (vectors at 0x2000_1000, \_start at 0x2000_1080) is the same in both modes, so one image runs whether it is loaded by the ROM or by the debugger.

## ROM Bootloader

Figure 6-1 shows the bootloader flow from UART initialisation to the jump into the application, including the failure path.

*[Figure 6‑1. ROM bootloader flow -- not reproduced]*

### UART0 Configuration

UART0 is the pulp apb_uart (obi_uart core, 16550-compatible, 16-byte RX FIFO). Its PADDR input is 3 bits wide and is forwarded as {PADDR, 2'b00} to the register file, so the UART wrapper connects PADDR = i_bus_apb_paddr\[4:2\] and register n of the 16550 map sits at byte offset 4 × n. The bit meanings of LCR, FCR and LSR are the standard 16550 ones.

| Register | Offset | Bootloader use |
|:---|:---|:---|
| RBR / THR / DLL | 0x00 | Receive byte / transmit byte / divisor low (DLAB = 1): DLL = 11. |
| IER / DLM | 0x04 | IER = 0 (no interrupt); DLM = 0 (DLAB = 1). |
| FCR | 0x08 | 0x07: enable FIFOs, clear RX and TX. |
| LCR | 0x0C | 0x80 (DLAB) while writing the divisor, then 0x03 (8N1). |
| LSR | 0x14 | Bit 0 DR (data ready), bits 1–3 OE/PE/FE (errors), bit 5 THRE, bit 6 TEMT. |

Table 6‑1. UART0 registers used by the bootloader (base 0x8002_4000)

Divisor 11 at 20 MHz gives 20 MHz / (16 × 11) = 113 636 baud, 1.36 % below 115200, which is inside the 8N1 tolerance. One byte takes 86.8 µs, about 1736 clock cycles.

### Image Format

| Offset | Size | Field | Checked by the ROM |
|:---|:---|:---|:---|
| 0x00 | 4 | MAGIC | Bytes 'Q','S','O','C' in that order (little-endian word 0x434F5351). |
| 0x04 | 4 | LENGTH | Payload bytes; multiple of 4; 4 … 61440. The PC pads the payload with 0x00. |
| 0x08 | 4 | LOAD_ADDR | Multiple of 4; ≥ 0x2000_1000; LOAD_ADDR + LENGTH ≤ 0x2001_0000. |
| 0x0C | 4 | ENTRY | Even (RV32IMC); LOAD_ADDR ≤ ENTRY \< LOAD_ADDR + LENGTH. |
| 0x10 | 4 | HDR_CRC | CRC32 of bytes 0x00–0x0F. |
| 0x14 | N | PAYLOAD | Raw bytes of the application .bin (objcopy -O binary). |
| 0x14 + N | 4 | PAY_CRC | CRC32 of PAYLOAD. |

Table 6‑2. Boot frame (all fields little-endian: least significant byte first)

CRC32 is the zlib/IEEE variant: reflected polynomial 0xEDB88320, initial value and final XOR 0xFFFFFFFF (zlib.crc32() on the PC, a bitwise loop in the ROM, one 32-bit word at a time in little-endian byte order). The header has its own CRC so that a corrupted header is rejected before the ROM trusts LENGTH or writes anything to RAM.

### Handshake

| Token | Sent when |
|:---|:---|
| QRDY | After UART0 initialisation, and after every failure once the line is drained. The PC may send a frame. |
| ACKH | Header received, HDR_CRC correct and all fields in range. The PC sends PAYLOAD + PAY_CRC. |
| ACKP | PAY_CRC correct. The ROM jumps to ENTRY. |
| FHCR | HDR_CRC mismatch. |
| FHDR | LENGTH, LOAD_ADDR or ENTRY out of range. |
| FPCR | PAY_CRC mismatch. |
| FTMO | More than about 100 ms between two bytes after the MAGIC. |
| FUAR | UART overrun, parity or framing error. |

Table 6‑3. Tokens sent by the ROM (always 4 ASCII bytes)

*[Figure 6‑2. PC loader – boot ROM handshake -- not reproduced]*

Tokens are readable in a terminal and the PC matches them with a 4-byte sliding window. Bytes received before the MAGIC (noise when the cable is plugged in or the terminal is opened) are skipped without a reply. If the PC opens the port after the ROM has already sent QRDY, it may send the frame directly: the ROM is waiting for the MAGIC.

### Failure and Retry

Every failure token is followed by the same recovery: the ROM clears its RX FIFO, discards incoming bytes until the line has been quiet for about 10 ms, sends QRDY and waits for a new frame. The PC resends the whole frame, up to a retry limit set in the loader. Nothing written to ISRAM before the failure is trusted: the next frame overwrites it. The watchdog is disabled after reset, so a download that never completes is not reset by the watchdog; the PC or a reset recovers it.

### Timeouts

Timeouts are loop counts, not timer values, because the bootloader uses no timer. One poll of LSR is an APB read through CPU2AXI, S_BUS and AXI2APB, estimated at 10 clock cycles or more.

| Constant | Value | Meaning |
|:---|:---|:---|
| RX_TIMEOUT | 200 000 polls | ≥ 2 M cycles = 100 ms at 20 MHz, between two bytes of one frame (after the MAGIC). |
| DRAIN_IDLE | 20 000 polls | ≥ 10 ms of quiet line ends the drain after a failure. |
| MAGIC hunt | no limit | The ROM waits for a frame indefinitely. |

Table 6‑4. Bootloader timeouts

Both counts are **minimums**: they assume the cheapest possible LSR poll (10 cycles through CPU2AXI, S_BUS, AXI2APB and P_BUS). A slower poll only makes the real timeout longer, which the protocol tolerates: the PC loader waits 2 s for an answer to the header and the payload time plus 2 s for the final token, and a ROM timeout could reach 2 s only if one poll took more than 200 cycles. The counts therefore need no tuning for correctness.

### Bootloader Algorithm

> boot_main:
>
> uart_init() // DLL=11, 8N1, FIFO on, IER=0
>
> loop forever:
>
> put_tok(boot_once()) // boot_once returns only on failure
>
> uart_drain() // clear FIFO, wait ~10 ms of silence
>
> boot_once:
>
> put_tok(QRDY)
>
> w = 0
>
> do { w = (w \>\> 8) \| (getc(no limit) \<\< 24) } while w != 'QSOC'
>
> read LENGTH, LOAD, ENTRY, HDR_CRC // getc(RX_TIMEOUT) -\> FTMO / FUAR
>
> if crc32(MAGIC..ENTRY) != HDR_CRC return FHCR
>
> if LENGTH/LOAD/ENTRY out of range return FHDR
>
> put_tok(ACKH)
>
> for a = LOAD; a != LOAD+LENGTH; a += 4:
>
> w = get32(); \*(uint32_t\*)a = w; crc = crc32_word(crc, w)
>
> if crc != get32() return FPCR
>
> put_tok(ACKP); wait LSR.TEMT // ACK fully sent before the app
>
> fence.i; jump ENTRY // never returns

The payload is written one 32-bit AXI word at a time. The SRAM controller has no byte-strobe path of its own, so writing single bytes would overwrite the other three bytes of the word; the bootloader always assembles four bytes before it writes. fence.i (encoded as .word 0x0000100F because recent GCC versions reject the mnemonic under -march=rv32imc) flushes Ibex's prefetch buffer so that no stale fetch survives the jump.

### Why Polling

The bootloader polls UART0 instead of using interrupts:

1.  It does not depend on the interrupt map, which is still being revised and whose NMI wiring is not settled.

2.  It fits the 1 KiB code budget: no interrupt handler, no register save/restore, no mie/mstatus set-up, no buffer shared between handler and main loop.

3.  The CPU has nothing else to do during boot, so an interrupt would only replace a polling loop with a wfi loop.

4.  It is fast enough: a byte arrives every ~1736 cycles, handling it (CRC + word assembly) takes about 100–300 cycles, and the 16-byte RX FIFO absorbs any delay, so no per-block acknowledge is needed.

5.  It is easy to debug on FPGA and in simulation: the flow is sequential and the waveform shows where it stops.

The application is free to use UART interrupts after the jump. The Day006 minutes mention both an interrupt-driven receive (③.2) and the ROM "watching the UART status" (⑥.1); the ROM owner has chosen polling for the reasons above, and the mandatory handshake (ACK/FAIL per step) required by the same minutes is independent of that choice.

## PC Tools

| Tool | Use |
|:---|:---|
| qsoc_image.py | Packs an application .bin into a frame: --load (default 0x2000_1000), --entry (default LOAD + 0x80). |
| qsoc_loader.py | Sends the frame over a USB-UART port (pyserial) and follows the handshake, with retry: python3 tools/qsoc_loader.py COM5 app.bin. |
| rom_model.py | Python model of boot.c, step by step. |
| test_protocol.py | Runs the loader against the model: good frame, noise before the MAGIC, bad header CRC, bad fields, bad payload CRC, timeout (make test). |

Table 7‑1. PC-side tools (design/rom/boot/tools)

Download time: at 113 636 baud a 60 KiB application takes about 5.3 s; a 22 KiB application about 2 s.

## Application Contract

- Link the image at LOAD_ADDR = 0x2000_1000 or higher; do not use the first 4 KiB of ISRAM (debug window).

- Use the same layout as the ROM: the 128-byte vector table at LOAD_ADDR (the application sets mtvec to it) and \_start at LOAD_ADDR + 0x80, so ENTRY = 0x2000_1080 for the default load address.

- Set up its own stack and data in DSRAM; the ROM leaves no state the application may rely on except UART0.

- UART0 is left configured: 113 636 baud 8N1, FIFOs enabled, interrupts disabled, transmitter empty.

- Clocks: every peripheral clock runs except TIMER1; enable TIMER1 in SCRC CLK_EN before using it.

- Read and clear SYSCSR RESET_CAUSE to learn whether this boot follows a power-on, watchdog or software reset.

LOAD_ADDR and ENTRY are separate fields because the first byte of the image is not the first instruction: the vector table comes first. Merging them would force the ROM to assume either ENTRY = LOAD (no vector table at the start of the image) or ENTRY = LOAD + 0x80 (a convention burned into the ROM forever). With ENTRY taken from the linker's entry point the image describes itself. The cost is 4 header bytes and three comparisons in the ROM.

## Verification Requirements

| ID | Requirement |
|:---|:---|
| BOOT_001 | After each reset source, the first Ibex fetch is at 0x0000_0080 and happens after every other domain is out of reset. |
| BOOT_002 | The ROM sends QRDY after reset and accepts a correct frame: ACKH, then ACKP, then execution starts at ENTRY. |
| BOOT_003 | Noise bytes before the MAGIC are ignored without a reply. |
| BOOT_004 | A wrong HDR_CRC gives FHCR and nothing is written to ISRAM. |
| BOOT_005 | Each out-of-range header field gives FHDR and nothing is written to ISRAM. |
| BOOT_006 | A wrong PAY_CRC gives FPCR and the ROM does not jump. |
| BOOT_007 | A gap longer than RX_TIMEOUT after the MAGIC gives FTMO; a UART error gives FUAR. |
| BOOT_008 | After every failure the ROM drains the line, sends QRDY and accepts a resent frame. |
| BOOT_009 | ISRAM contents after ACKP equal the payload, word for word, at LOAD_ADDR. |
| BOOT_010 | With DBG_EN = 1 the CPU stays in reset until CPUHOLD = 0 and then starts at 0x2000_1080; with DBG_EN = 0 it starts at 0x0000_0080 without extra delay. |
| BOOT_011 | The ROM build fails if the bootloader exceeds the 1 KiB code budget (make size) or the 2 KiB ROM (link.ld). |

Table 9‑1. Verification requirements

## Acronyms

| Acronyms      | Description                                 |
|:--------------|:--------------------------------------------|
| CRC           | Cyclic Redundancy Check                     |
| DSRAM / ISRAM | Data SRAM / Instruction SRAM                |
| FIFO          | First-In First-Out buffer                   |
| JTAG          | Joint Test Action Group (debug port)        |
| LSR           | Line Status Register (UART)                 |
| MRV-CPU       | Mini RISC-V CPU inside SCRC                 |
| POR           | Power-On Reset                              |
| RRC           | Reset Request Controller                    |
| SCRC          | System Clock & Reset Controller             |
| SYSDBG        | System Debugger                             |
| UART          | Universal Asynchronous Receiver-Transmitter |

## First Review

| Comment | Reviewer | Response |
|:---|:---|:---|
| The handshake must be mandatory: ACK/FAIL after each step (single-shot without ACK is not acceptable). | Quan (mentor), Day006 | Accepted (V2.0): token handshake, Section 6.3. |
| Keep the image format simple; separate the header check from the payload check. | Quan (mentor), Day006 | Accepted (V2.0): HDR_CRC + PAY_CRC. |
| Why are LOAD_ADDR and ENTRY separate? | Quan (mentor) | Answered in Section 8. |
| No reason to release ROM/RAM first; release all domains together, CPU last. | Quan (mentor), 24/09 | Accepted (V2.0): Section 4.1. |
| Race: CPU released before the UART0 guard opens. | Review (V2.2) | Fixed (V2.2): guards opened before the CPU release, Section 4.1; SCRC V2.3 Section 7.2. |
| Reset vector is ROM base + 0x80. | Sinh | Accepted (V1.2): Section 4.2. |
| Debug boot: DBG_EN pin, CPU held until CPUHOLD = 0, boot address 0x2000_1000. | SYSDBG owner (MAS V3.0) | Accepted (V2.1): Section 5. |
| UART register offsets. | UART wrapper (apb_uart RTL) | Resolved (V2.1): PADDR = i_bus_apb_paddr\[4:2\], register n at 4 × n, Section 6.1. |
