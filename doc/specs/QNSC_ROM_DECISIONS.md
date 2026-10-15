# QNSC_ROM — design decisions and record

**This is not the specification.** That is [`QNSC_ROM_MAS.md`](QNSC_ROM_MAS.md).

This file holds why V3.0 differs from V2.1, and the V2.1 document by Nguyen Hao
Nam, kept whole below. Its figure is not reproduced: it was in colour and is
replaced by the figures of the specification.

---

# 0. V3.1 to V3.2

| Change | Why |
|---|---|
| The write-error responder moved from hand-written logic in `m_qnsc_wrap_rom` to its own module, `m_qnsc_rom_wr_resp`, instantiated by the wrapper | A wrapper is generated with emacs verilog-mode (`CONTRIBUTING.md` step 3), whose AUTOs declare only ports that reach an instance. Logic and ports inside the wrapper would need hand-declared ports, which the flow forbids. Behaviour unchanged |

# 1. V2.1 to V3.0

The ROM design is V2.1's. V3.0 is a move onto the MAS template by the lead.

| Change | Why |
|---|---|
| `initial $readmemh` into `logic mem[0:511]` replaced by a generated `m_qnsc_rom_image` (`case` + output register) | ASIC synthesis ignores `initial`, or maps the array to 16 Kbit of flip-flops with an initial value that silicon does not have. A `case` over constants synthesises to logic. The libraries have no ROM macro (V2.1 section 1) |
| `util/gen_rom.py` and a CI regenerate-and-compare check | The same rule as `qnsc_pkg.sv`: a generated file that can drift from its source is a copy |
| Ports `i_bus_axi_araddr` to `i_bus_axi_ar_addr` and similar | Match `QNSC_RAM_MAS` Table 5-1: one controller, one set of port names |
| Read-path properties replaced by references to `QNSC_RAM_MAS` 7.1, 7.2, 7.4, 7.6 | Same controller, same parameters; two descriptions would drift |
| Read latency stated (4 cycles, one beat per 2 cycles) | From `QNSC_RAM_MAS` 7.1; V2.1 gave none |
| Responder: "waits for AW before W" and "reads continue meanwhile" stated; `ROM_005` added | Both are AXI-legal choices a reviewer asks about |
| "If the order were wrong, AXI keeps VALID low in reset" replaced by "every `S_BUS` master is in reset whenever the ROM is" | The controller's `ARREADY` is 1 in reset (`QNSC_RAM_MAS` 7.6), so the V2.1 argument did not hold; the reset tree is what guarantees it |
| Debug-boot paragraph cut to one row in section 9 | Owned by `QNSC_SYSDBG_MAS` 7.1 |
| Controller sub-module table cut to one row | Internal to vendored IP |
| Build-flow file table moved to the open items | The files are not in the repository yet; the bootloader is the Booting Flow specification |
| `ROM_005` of V2.1 (decode error above `0x7FF`) removed; `ROM_008` added | The decode error is an `S_BUS` check. `ROM_008` fails if the image goes back to an array |
| `design/rom/README.md`: table-driven CRC "about 2.1 KiB" corrected | The table is 1 KiB; with the code it exceeds 1920 B |
| Code budget (1 KiB), CRC choice, `sp` value, `link.ld`/`make size` checks moved out | Bootloader content, not ROM hardware: they are now `QNSC_BOOT_SPEC` 8. The ROM keeps the one hardware limit, 2048 bytes, enforced by `util/gen_rom.py` |
| Image ports `i_mem_oe`, `i_mem_addr[8:0]`, `o_mem_rdata`; no reset | The RAM macro port names, since the image stands where the macro stands. A constant needs no reset; the output is sampled only after `i_mem_oe` |
| Burst past `0x7FF` wraps to word 0, stated as an accepted limit | `S_BUS` decodes the start address only and the image ignores address bits above `[10:2]` |
| HAS row on the Table 13-4 size estimate removed | Not a departure: the HAS only says the bootloader fits |
| `ROM_004` burst lengths 1, 2, 16, 256 | The responder claims any length; 256 is the AXI maximum |

---

# V2.1 as issued

## Reversion and History

| Version | Date (mm/dd/yyyy) | Author | Reviewer | Description of Change |
|:---|:---|:---|:---|:---|
| V1.0 | 09/19/2026 | Nguyen Hao Nam | \- | Initial ROM specification on AXI4-SRAM-CONTROLLER. |
| V1.1 | 09/21/2026 | Nguyen Hao Nam | Nguyen Hung Quan | 2 KiB size, read-only by tie-off, SLVERR recommendation for writes. |
| V1.2 | 09/21/2026 | Nguyen Hao Nam | Huynh Phuoc Truong Sinh | Reset vector ROM base + 0x80; crossbar window 0x0000–0x07FF; rewritten in English. |
| V2.0 | 09/24/2026 | Nguyen Hao Nam | \- | Rewritten on the QNSC document template: layout forced by Ibex (128 B vectors + 1920 B code), ROM content build flow from design/rom/boot, byte-to-word index in the wrapper, reset release together with other domains (CPU last), updated open issues; stale 1158 B size estimate removed. |
| V2.1 | 09/24/2026 | Nguyen Hao Nam | \- | Open issues closed: PARA_ID_WD = 7; write-error responder (SLVERR) inside the wrapper; size limits enforced by link.ld and make size; licence and debugger access recorded; wrapper ports renamed to the SoC naming rule (i_clk_mem, i_bus_axi\_\*); debug-boot note. |


## Overview

The QSOC boot ROM is a 2 KiB read-only memory at address **0x0000_0000**, connected to S_BUS port AXI_M0. Because QSOC has no Flash, the ROM holds the only code present when the chip leaves reset: Ibex fetches its first instruction from it, and the serial bootloader it contains is the only way to put an application into RAM.

The ROM reuses the AXI4 memory controller of the RAMs (nguyenquanicd/AXI4-SRAM-CONTROLLER, top module m_vlsi_axi4_sram). The ROM wrapper m_qnsc_wrap_rom ties the controller's write channel to its idle state and places behind it a 512 × 32-bit array whose contents are loaded at build time from rom_image.hex. It is not a mask ROM or OTP: the project libraries provide neither, so read-only is enforced by the wrapper.

This document specifies the ROM hardware: the wrapper, the address map, the memory layout forced by Ibex, the build of the ROM contents and the clock/reset. What the bootloader does is specified in the Booting Flow specification; the bootloader source is repo implement/vlsi_deep_training/design/rom/boot/.

## Feature

- 2 KiB (512 words × 32 bits) at 0x0000_0000 – 0x0000_07FF on AXI_M0.

- AXI4 subordinate built on m_vlsi_axi4_sram; read channels (AR, R) used, write channels (AW, W, B) tied off in the wrapper.

- Contents fixed at build time (\$readmemh("rom_image.hex")), generated from the bootloader source.

- Layout forced by Ibex: 128-byte trap vector table at 0x000, first instruction at 0x080 ({boot_addr_i\[31:8\], 8'h80}).

- Instruction fetch and data read (constants are encoded as immediates, but reads are allowed).

- Always-on clock domain (never gated); reset released together with the other domains, before the CPU.

## Block Diagram

The wrapper contains the vendored controller and the memory array; nothing else is added.

*[Figure 3‑1. ROM wrapper block diagram -- not reproduced]*

| Module | Role |
|:---|:---|
| m_vlsi_axi4_sram | Top level of the controller. |
| m_vlsi_axfsm × 2 | AW and AR address FSMs: VALID/READY handshake and per-beat address generation. |
| m_vlsi_fifo × 5 | AW, W, AR, R and B FIFOs between the AXI handshake and the SRAM timing. |
| m_vlsi_arbiter | Round-robin arbitration between read and write requests. |
| m_vlsi_sram_misc | SRAM port multiplexing, R/B response generation. |

Table 3‑1. Sub-modules of m_vlsi_axi4_sram

## Interface

| Port group | Signals | ROM connection |
|:---|:---|:---|
| Clock / reset | i_clk_mem, i_rst_n_mem | mem cluster (SoC contract naming): SCRC o_clk_rom, o_rst_rom_n. |
| AR | i_bus_axi_araddr\[31:0\], i_bus_axi_arvalid, o_bus_axi_arready, i_bus_axi_arburst, i_bus_axi_arlen, i_bus_axi_arid\[6:0\] | S_BUS AXI_M0 → controller AR. |
| R | o_bus_axi_rid, o_bus_axi_rdata\[31:0\], o_bus_axi_rresp, o_bus_axi_rvalid, o_bus_axi_rlast, i_bus_axi_rready | Controller R → S_BUS AXI_M0. |
| AW / W / B | i_bus_axi_aw\*, i_bus_axi_w\*, o_bus_axi_b\* | Served by the write-error responder in the wrapper (Section 5.3); the controller's own write channel is tied idle. |

Table 4‑1. ROM wrapper ports

| Parameter | Default | ROM value | Note |
|:---|:---|:---|:---|
| PARA_DATA_WD | 32 | 32 | Ibex / S_BUS data width. |
| PARA_ADDR_WD | 32 | 32 | Full address at the port; the array uses bits \[10:2\]. |
| PARA_ID_WD | 4 | 7 | S_BUS master-port ID width (HAS Table 5-1), the same value as ISRAM/DSRAM (RAM MAS V2.1). |
| PARA_LEN_WD | 8 | 8 | Bursts up to 256 beats. |
| PARA_FIFO_DEPTH | 8 | 8 | No reason to change for v1. |

Table 4‑2. Controller parameters used by the ROM

## Functional Description

### Read Path

These properties come from the vendored controller (m_vlsi_sram_misc) and are not designed by the ROM:

- Synchronous array with one-cycle latency: o_sram_oe is asserted in the issue cycle and the read data is captured in the next cycle into the R FIFO.

- One outstanding read at a time (reg_rd_pending blocks a new read until the previous one returns).

- RRESP is always OKAY; the controller cannot report an out-of-range access. Decode errors are produced by S_BUS.

- AxSIZE is not supported: every beat is a full 32-bit word.

- WRAP bursts are declared but not implemented by the controller (noted by the RAM owner); Ibex instruction fetch does not use them.

### Memory Array

The array is written inside the wrapper, not as a separate module. o_sram_addr from the controller is a **byte** address; converting it to a word index (dropping bits \[1:0\]) is the wrapper's job, not the controller's.

> logic \[31:0\] mem \[0:511\]; // 2 KiB = 512 words
>
> initial \$readmemh("rom_image.hex", mem); // built by design/rom/boot
>
> always_ff @(posedge i_clk_mem)
>
> if (w_sram_oe)
>
> w_sram_rdata \<= mem\[w_sram_addr\[10:2\]\]; // byte address -\> word index

rom_image.hex is the ROM's static content (the compiled bootloader). It is different from the application image that the bootloader receives over UART at run time.

### Write Channel

> i_awaddr = '0; i_awvalid = 1'b0; // o_awready unused
>
> i_wdata = '0; i_wvalid = 1'b0; // o_wready unused
>
> i_bready = 1'b1; // o_bid / o_bresp / o_bvalid unused

The controller's write channel is tied idle, so a write can never reach the array. A write addressed to the ROM must still be answered on AXI_M0, otherwise the master waits forever; S_BUS forwards it like any other access to AXI_M0. The ROM wrapper therefore contains a small **write-error responder**:

1.  Idle: o_bus_axi_awready = 1. On an AW handshake, store awid and go to DATA.

2.  DATA: o_bus_axi_wready = 1; accept and discard W beats until wlast, so a burst of any length is drained.

3.  RESP: o_bus_axi_bvalid = 1, bid = stored ID, bresp = 2'b10 (SLVERR); back to Idle on bready.

A stray write therefore ends as a store access fault in Ibex (or an error seen by SYSDBG or DMA) instead of a silent success. The responder is local to the wrapper, so it needs no S_BUS configuration and no change to the vendored controller.

## Address Map and Memory Layout

| Attribute | Value | Note |
|:---|:---|:---|
| Base address | 0x0000_0000 | S_BUS AXI_M0; boot_addr_i of Ibex is tied to this base. |
| Size | 2 KiB (512 × 32-bit) | Day005 review; SoC contract util/qsoc_contract.yml. |
| Range | 0x0000_0000 – 0x0000_07FF | An access outside it is a decode error from S_BUS. |
| Access | Read / execute | Writes answered with SLVERR, Section 5.3. |

Table 6‑1. ROM address map

Ibex fetches its first instruction from {boot_addr_i\[31:8\], 8'h80} = 0x0000_0080 (ibex_if_stage.sv), and mtvec resets to boot_addr_i in vectored mode. The first 128 bytes therefore hold the 32-entry trap vector table (cause 31 is the NMI). This fixes the layout:

| Offset | Size | Content |
|:---|:---|:---|
| 0x000 – 0x07F | 128 B | Trap vector table: 32 × j rom_trap (4-byte, uncompressed). A trap during boot parks the core; only a reset leaves it. |
| 0x080 | — | \_start: set sp to the top of DSRAM (0x3000_8000), call boot_main. |
| 0x080 – 0x7FF | 1920 B | All bootloader code. No .data, no .bss (no RAM initialisation exists before the bootloader); tokens are immediates, so no .rodata. |

Table 6‑2. ROM memory layout

The code budget from the Day005 review is 1 KiB. The bitwise CRC32 is used because the table-driven version (with its 1 KiB table) does not fit in 1920 bytes. Both limits are enforced by the build, not by review: link.ld stops the link if the image exceeds 2 KiB or uses .data/.bss, and make size fails if the code exceeds the 1 KiB budget, so a ROM image that violates them cannot be produced.

## ROM Content Build

The ROM content is software built from design/rom/boot/; its only output used by the hardware is rom_image.hex.

| File | Content |
|:---|:---|
| boot.h | Memory map, UART0 registers, timeouts, frame format and handshake tokens. Single source of truth for the format. |
| crt0.S | 128-byte trap table and \_start at 0x80. |
| boot.c | The serial bootloader. |
| link.ld | 2 KiB layout; asserts that the vector table is 128 B, that .data/.bss are empty and that the image fits in 2 KiB. |
| Makefile | Build (make CROSS=riscv64-unknown-elf-), size check (make size), protocol test (make test). |
| tools/bin2hex.py | boot.bin → rom_image.hex (512 × 32-bit words, little-endian). |

Table 7‑1. Bootloader source files

1.  Compile crt0.S and boot.c for RV32IMC and link with link.ld → boot.elf.

2.  objcopy -O binary → boot.bin.

3.  tools/bin2hex.py → rom_image.hex, padded to 512 words.

4.  The wrapper loads it with \$readmemh; synthesis maps the initialised array to ROM/constant logic.

## Clock and Reset

| Signal | Source | Note |
|:---|:---|:---|
| i_clk_mem | SCRC o_clk_rom | Always-on; the ROM clock is never gated. |
| i_rst_n_mem | SCRC o_rst_rom_n | Asserted by POR, watchdog and software reset; released together with every other domain; the CPU is released 16 cycles later. |

Table 8‑1. ROM clock and reset

In debug boot (DBG_EN = 1, SYSDBG MAS V3.0) Ibex starts at 0x2000_1080 in ISRAM and does not execute the ROM; to debug the bootloader itself the host halts the core before its first instruction and sets dpc = 0x0000_0080.

Because the ROM leaves reset 16 cycles before Ibex and Ibex needs 2 more cycles before its first request, the first fetch always finds the ROM ready. Even if the order were wrong, the result would not be corruption: AXI requires VALID to stay low during reset, so a ROM still in reset cannot return data and Ibex would simply wait. The risk of a wrong order is liveness only.

## Verification Requirements

| ID | Requirement |
|:---|:---|
| ROM_001 | After reset, a read of any word returns the matching word of rom_image.hex. |
| ROM_002 | INCR bursts of 1–16 beats return consecutive words with RLAST on the last beat and RRESP = OKAY. |
| ROM_003 | The first Ibex fetch after reset is at 0x0000_0080 and returns the first instruction of \_start. |
| ROM_004 | A write to the ROM range does not change any word and completes on the bus with BRESP = SLVERR, for bursts of 1–16 beats. |
| ROM_005 | An access above 0x0000_07FF never reaches the ROM (S_BUS decode error). |
| ROM_006 | make fails if the bootloader exceeds the 1 KiB code budget or the 2 KiB ROM, or uses .data/.bss. |
| ROM_007 | SYSDBG (AXI_S0) reads every ROM word through S_BUS and gets the rom_image.hex contents. |

Table 9‑1. Verification requirements

## Acronyms

| Acronyms      | Description                     |
|:--------------|:--------------------------------|
| AXI           | Advanced eXtensible Interface   |
| CRC           | Cyclic Redundancy Check         |
| DSRAM / ISRAM | Data SRAM / Instruction SRAM    |
| NMI           | Non-Maskable Interrupt          |
| OTP           | One-Time Programmable memory    |
| ROM           | Read-Only Memory                |
| S_BUS         | System bus (AXI4 crossbar)      |
| SCRC          | System Clock & Reset Controller |

## First Review

| Comment | Reviewer | Response |
|:---|:---|:---|
| Reset vector is boot_addr_i + 0x80, not 0x0; boot_addr_i is a port of ibex_top. | Sinh | Accepted (V1.2): layout in Section 6. |
| ROM size is 2 KiB; the crossbar window must match (no 8 KiB aliasing). | Sinh | Accepted (V1.2): 0x0000_0000 – 0x0000_07FF. |
| o_sram_addr is a byte address; the word index conversion belongs to the wrapper. | Nam (RTL check) | Accepted (V2.0): Section 5.2. |
| Reset release order: all domains together, CPU last. | Quan (mentor) | Accepted (V2.0): Section 8. |
| PARA_ID_WD = 7 for every memory on S_BUS. | RAM owner (RAM MAS V2.1) | Accepted (V2.1): Table 4-2. |
| A write to the ROM must not hang the master. | Nam (bus review) | Accepted (V2.1): write-error responder in the wrapper, Section 5.3. |
| Licence of AXI4-SRAM-CONTROLLER. | Mentor | Recorded as MentorProvided-QNSC-Course in vendor/manifest.yml (the mentor's own course repository). |
| Can the debugger read the ROM? | SYSDBG owner | Yes: axi_xbar is fully connected, AXI_S0 reaches AXI_M0 (SYSDBG MAS V3.0). |
