# QNSC_SYSCSR — design decisions and record

**This is not the specification.** That is [`QNSC_SYSCSR_MAS.md`](QNSC_SYSCSR_MAS.md).

This file holds why V3.0 differs from V2.2, and the V2.2 document by Nguyen Hao
Nam, kept whole below. Its figure is not reproduced: it was the V2.3 `SCRC`
figure, in colour, and is replaced by the three figures of the specification.

---

# 0. V3.0 to V3.1

| Change | Why |
|---|---|
| Block directory `design/scrc` to `design/syscsr`; wrapper `m_qnsc_syscsr` to `m_qnsc_wrap_syscsr` | SYSCSR has its own APB slave (`APB_M1`), its own clock cluster (`cpu`) and its own name in the contract, so it is a block: one wrapper, one directory. Under `design/scrc` its filelist also dragged a second top module into the SCRC lint |
| Wrapper generated with emacs verilog-mode | It only instantiates and renames, which is what `CONTRIBUTING.md` step 3 generates |
| `CHIP_ID_REV` from the port `i_cfg_chip_id` instead of `qnsc_pkg::C_CHIP_ID` | Outside `design/scrc` the block is IP (`flow/lint/module_rules.yml`) and may not use `qnsc_pkg`; a chip value reaches IP on an `i_cfg_*` port that `design/top` ties (`design/README.md`, "Shared numbers"). Still one source |

# 1. V2.2 to V3.0

V3.0 is a move onto the MAS template by the lead, aligned with `QNSC_SCRC_MAS`
V3.0. The three registers, their offsets and reset values are V2.2's.

| Change | Why |
|---|---|
| `APB_S1` renamed `APB_M1` | Contract name of the `P_BUS` subordinate port |
| `m_scrc_syscsr` split into wrapper `m_qnsc_syscsr` (in `design/scrc/rtl`) and generated `m_qnsc_syscsr_csr` (in `util/gen/syscsr`) | Naming Rule 2.1 for the module; the generator's own ports (`i_bus_rstn`, `i_paddr`) fail rules 1.2--1.3 and cannot be renamed at the tool, so the generated file stays outside `design/`, as `vendor/manifest.yml` already describes for APB-BUS-Generator |
| Wrapper ports `i_clk_cpu`, `i_rst_n_por`, `i_bus_apb_*`, `i_cause_we_*`, `i_domain_rst_stat[31:0]` | Naming Rule; one 32-bit status vector instead of 19 ports, so `design/top` builds it in one line per bit |
| `CHIP_ID_REV` from `qnsc_pkg::C_CHIP_ID`, new `meta.chip_id` in the contract | The value was mistyped once ('QCOS'); it is also used by the PC loader and the debugger, so it is a shared fact. `hardcode_check` now rejects the literal in RTL |
| `stat_spi_device` (bit 13) reserved; `stat_timer0` renamed `stat_timer_0` and similar | `QNSC_SCRC_MAS` V3.0: one SPI domain; Naming Rule 1.4 |
| Set enables are levels held for the whole chip reset, not one-cycle pulses | Read from `CSR_Generation.py`: for a `w1c` field `nxt = we ? (~pwdata & reg) : hw_we ? hw_wdata : reg`, so an APB write in the same cycle wins. A firmware clear of `0x7` meeting a one-cycle WDT pulse would lose the WDT cause. Holding the enable for the 16 cycles closes it: `P_BUS` is in reset from the first cycle, so the later cycles cannot see an APB write. `SYSCSR_008` |
| Access timing stated: one wait state, `PSLVERR` with none | Read from the generator; DV and the `P_BUS` owner need it |
| Post-boot `DOMAIN_RST_STATUS` values stated: `0x10`, `0x8000_0010` in debug boot | `timer_1` stays in reset after boot because it is gated; a reader who expects 0 files a bug |
| Byte stores fault | The generator rejects a write with `PSTRB` != `4'hF`; V2.2 stated it but not the consequence for firmware |
| "Workbook and generation notes" section removed; location in section 4 and 11 | It referred to `repo implement/APB-CSR-Generator/RTL/`, which is not in this repository |
| HAS departures listed | HAS Table 9-1/9-2 still describe the peripheral-bus reset, `cause_por` reset 0 and four GPIO |
| Source column merged into the interface table; the separate "where each input comes from" table removed | Same signals listed twice |
| Figure labels are the field names (`cause_por`, `stat_timer_0`), `CHIP_ID_REV` drawn as one field | A figure that says `por` while the table says `cause_por` is two names for one bit |
| `syscsr` added to the `cpu` cluster in the contract | `i_clk_cpu` named a cluster that did not list the block |
| Contract `chip_id` comment: "firmware and host tools through `SYSDBG`" | The PC loader talks to the boot ROM over UART and cannot read a register |
| Firmware use kept as three lines (7.5) | V2.2 section 8; start-up read-and-clear is the one sequence every application needs |
| Revision-field row removed from section 9 | Said twice; the field table says "no revision field" |
| Requirement "SPI, TIMER, PWM MAS use the SCRC bit numbers" removed | It belongs to `QNSC_SCRC_MAS` 11, where it already is |

---

# V2.2 as issued

## Reversion and History

| Version | Date (mm/dd/yyyy) | Author | Reviewer | Description of Change |
|:---|:---|:---|:---|:---|
| V1.0 | 09/20/2026 | Nguyen Hao Nam | \- | Initial SYSCSR register specification for APB-CSR-Generator. |
| V1.1 | 09/21/2026 | Nguyen Hao Nam | Huynh Phuoc Truong Sinh | RESET_CAUSE reduced to POR/WDT/SOFT; CHIP_ID_REV = 0x51534F43 without REV field; MRV_BUSY removed; rewritten in English. |
| V2.0 | 09/24/2026 | Nguyen Hao Nam | \- | Rewritten on the QNSC document template to match SCRC V2.0: reset by POR only (o_rst_por_n), cause_por reset value 1, cause set by RRC write enables; DOMAIN_RST_STATUS extended to the 19-bit domain map plus stat_cpu at bit 31; field renames (sbus, pbus, gpio0); base address 0x8000_4000; SYSCTL references removed. |
| V2.1 | 09/24/2026 | Nguyen Hao Nam | \- | Open issues closed: stat_cpu \[31\] final; address connection rule for any P_BUS width; stat_gpio3 removed (40-pin package), bit 18 reserved; figure translated to English. |
| V2.2 | 09/24/2026 | Nguyen Hao Nam | \- | i_slverr_en behaviour stated as the generator implements it (misaligned address, partial-strobe write; unused offsets read 0 without error); SYSCSR regenerated. |


## Overview

SYSCSR (System Control and Status Registers) is the status register block of the QSOC clock/reset subsystem. It tells software why the chip was last reset (RESET_CAUSE), which domains are currently held in reset (DOMAIN_RST_STATUS) and which chip it is running on (CHIP_ID_REV).

SYSCSR is a separate APB slave (APB_S1) on P_BUS at base address **0x8000_4000** with a 16 KiB window. It is generated with APB-CSR-Generator (module m_scrc_syscsr) and is owned by the SCRC owner. All fields are written by hardware and read by software; the only software write is the write-1-to-clear of RESET_CAUSE. Control registers (SW_RST, CLK_EN, SOFT_RST_CTRL, ...) are not in SYSCSR: they are in SCRC CSR, specified in the SCRC Micro-Architecture Specification.

The defining property of SYSCSR is its reset: it is reset by the power-on reset only (o_rst_por_n from the SCRC Reset Request Controller). A watchdog or software reset therefore leaves RESET_CAUSE intact, so the code that runs after the reset can read what caused it.

## Feature

- Three 32-bit registers in one APB slave: RESET_CAUSE, DOMAIN_RST_STATUS, CHIP_ID_REV.

- RESET_CAUSE: one sticky bit per reset source (POR, WDT, SOFT), set by hardware, cleared by software with write-1-to-clear. More than one bit can be set.

- DOMAIN_RST_STATUS: live reset state of every SCRC output domain, with the same bit map as the SCRC control registers (18 domain bits plus the CPU at bit 31).

- CHIP_ID_REV: constant 0x51534F43 ('QSOC').

- Reset by power-on reset only; clocked by the always-on P_BUS clock.

- Generated with APB-CSR-Generator; field types ro and w1c only.

## Block Diagram

Figure 3-1 shows SYSCSR in its context. SYSCSR sits outside the SCRC module; SCRC provides its reset (o_rst_por_n) and the reset-cause write enables, and the SoC top drives DOMAIN_RST_STATUS from the SCRC domain reset outputs.

*[Figure 3‑1. SYSCSR in the SCRC context (top right) -- not reproduced]*

| Connection | From | Meaning |
|:---|:---|:---|
| APB slave port | P_BUS APB_S1 | Register access by Ibex (and by SYSDBG through S_BUS). |
| i_bus_clk | SCRC o_clk_pbus | Always-on P_BUS clock. |
| i_bus_rstn | SCRC o_rst_por_n | POR-only reset. Must not be o_rst_pbus_n, otherwise a WDT/SW reset clears RESET_CAUSE. |
| i_hw_we_resetcause_cause_wdt / \_soft | SCRC o_cause_we_wdt / o_cause_we_sw | One-cycle pulse that sets the cause bit. |
| i_domainrststatus_stat\_\<d\> | SoC top: ~o_rst\_\<d\>\_n | Live reset state of domain d. |
| i_chipidrev_chip_id_rev | tie-off | 32'h51534F43. |

Table 3‑1. SYSCSR connections

## Interface

### Generator Configuration

| Config | Value | Note |
|:---|:---|:---|
| Module name | m_scrc_syscsr | Output file m_scrc_syscsr.sv. |
| Protocol | APB | Fixed by the tool. |
| Data width | 32 | Fixed by the tool. |
| Address width | 16 | Fixed by the tool; only offsets 0x0000–0x0008 are used. The SoC top connects the P_BUS address bits it has (12 or more, set by the bus owner for all slaves) and ties the rest of the 16 bits to 0; the register decode is the same for any width. |
| Asynchronous | 0 | Register clock = bus clock (o_clk_pbus), so no synchronizer model is needed. |

Table 4‑1. APB-CSR-Generator configuration

### Port List

| Port | Dir | Width | Description |
|:---|:---|:---|:---|
| i_bus_clk | in | 1 | o_clk_pbus. |
| i_bus_rstn | in | 1 | o_rst_por_n (POR only). |
| i_psel, i_penable, i_pwrite | in | 1 each | APB control. |
| i_paddr | in | 16 | Offset. |
| i_pwdata, i_pstrb, i_pprot | in | 32, 4, 3 | APB4 write data / strobe / protection. |
| i_protect_en, i_slverr_en | in | 1, 1 | Generator options: tie i_protect_en = 0; tie i_slverr_en = 1, which makes the block return PSLVERR for a misaligned address or a write with incomplete byte strobes. An unused offset reads 0 and ignores writes without an error (generator behaviour). |
| o_prdata, o_pready, o_pslverr | out | 32, 1, 1 | APB response. |
| i_hw_we_resetcause_cause\_\<c\>, i_hw_wdata_resetcause_cause\_\<c\> | in | 1, 1 | Hardware set of cause bit c (por, wdt, soft). |
| o_resetcause_cause\_\<c\> | out | 1 | Current value of cause bit c (generated by the tool for w1c fields; unused). |
| i_domainrststatus_stat\_\<d\> | in | 1 each | 19 status inputs (Table 6-3). |
| i_chipidrev_chip_id_rev | in | 32 | Chip ID constant. |

Table 4‑2. SYSCSR ports

## Functional Description

### Reset and Clock

SYSCSR runs on o_clk_pbus, which is never gated, and is reset by o_rst_por_n, which follows the power-on reset only. The consequences are:

- After a POR every register is at its reset value; RESET_CAUSE reads 0x1 (POR).

- After a WDT or software reset the SYSCSR flip-flops keep their values; RRC sets the new cause bit with a one-cycle write enable while the rest of the chip is held in reset.

- SYSCSR is readable as soon as P_BUS and Ibex leave reset; it needs no initialisation by software.

### Reset Cause Capture

- **POR** — no hardware set is needed: cause_por has reset value 1 and the register is reset only by POR. i_hw_we_resetcause_cause_por is tied to 0.

- **WDT** — RRC pulses o_cause_we_wdt for one cycle when it starts a reset caused by the (synchronized) watchdog request.

- **SOFT** — RRC pulses o_cause_we_sw for one cycle when it starts a reset caused by SW_RST.

- i_hw_wdata_resetcause_cause\_\* are tied to 1 (a write enable always sets the bit).

Bits are sticky until software clears them. If software does not clear RESET_CAUSE between two resets, several bits can be set at the same time (for example POR and WDT); each bit means that this source has caused at least one reset since the bit was last cleared.

### Domain Reset Status

Each DOMAIN_RST_STATUS bit is the inverse of the matching SCRC domain reset output, connected at the SoC top without registers. A bit reads 1 while the domain is held in reset, whether by a chip reset, a peripheral soft reset (SOFT_RST_CTRL) or, for the CPU, the debug hold. Because it follows the reset synchronizer output, a domain whose clock is gated keeps reading 1 after its soft reset is released, until its clock is enabled again.

## Register Description

### Register Map

| Offset | Register | Access | Reset value | Description |
|:---|:---|:---|:---|:---|
| 0x0000 | RESET_CAUSE | R/W1C | 0x0000_0001 | Sticky cause of the last reset(s). |
| 0x0004 | DOMAIN_RST_STATUS | RO | see Table 6-3 | Live reset state per domain (1 = held in reset). |
| 0x0008 | CHIP_ID_REV | RO | 0x5153_4F43 | Chip identifier 'QSOC'. |

Table 6‑1. SYSCSR register map (base 0x8000_4000)

The tables below are written in the APB-CSR-Generator workbook layout (REGISTER, OFFSET, BIT NAME, FIELD WIDTH, BIT TYPE, RESET VALUE, DESCRIPTION) so they can be copied into the workbook directly.

### RESET_CAUSE (0x0000)

| Bit name | Bits | Type | Reset | Description |
|:---|:---|:---|:---|:---|
| cause_por | \[0\] | w1c | 0x1 | Power-on reset occurred. Set by the POR itself (reset value). Write 1 to clear. |
| cause_wdt | \[1\] | w1c | 0x0 | Watchdog reset occurred. Set by o_cause_we_wdt. Write 1 to clear. |
| cause_soft | \[2\] | w1c | 0x0 | Software reset (SW_RST) occurred. Set by o_cause_we_sw. Write 1 to clear. |
| reserved | \[31:3\] | ro | 0x0 | Read as zero, writes ignored. |

Table 6‑2. RESET_CAUSE fields

### DOMAIN_RST_STATUS (0x0004)

The bit map is the SCRC domain bit map (SCRC specification, Table 6-2). Bits 0–13 keep the positions of the previous version; bits 14–17 and 31 are new in v2.0; bit 18 (GPIO3) was removed with the 40-pin package and is reserved.

| Bit name        | Bits      | Type | Reset | Source (SoC top)        |
|:----------------|:----------|:-----|:------|:------------------------|
| stat_sbus       | \[0\]     | ro   | —     | ~o_rst_sbus_n           |
| stat_pbus       | \[1\]     | ro   | —     | ~o_rst_pbus_n           |
| stat_wdt        | \[2\]     | ro   | —     | ~o_rst_wdt_n            |
| stat_timer0     | \[3\]     | ro   | —     | ~o_rst_timer0_n         |
| stat_timer1     | \[4\]     | ro   | —     | ~o_rst_timer1_n         |
| stat_uart0      | \[5\]     | ro   | —     | ~o_rst_uart0_n          |
| stat_uart1      | \[6\]     | ro   | —     | ~o_rst_uart1_n          |
| stat_spi        | \[7\]     | ro   | —     | ~o_rst_spi_n (SPI host) |
| stat_i2c        | \[8\]     | ro   | —     | ~o_rst_i2c_n            |
| stat_gpio0      | \[9\]     | ro   | —     | ~o_rst_gpio0_n          |
| stat_dma        | \[10\]    | ro   | —     | ~o_rst_dma_n            |
| stat_rom        | \[11\]    | ro   | —     | ~o_rst_rom_n            |
| stat_ram        | \[12\]    | ro   | —     | ~o_rst_ram_n            |
| stat_spi_device | \[13\]    | ro   | —     | ~o_rst_spi_device_n     |
| stat_sysdbg     | \[14\]    | ro   | —     | ~o_rst_sysdbg_por_n     |
| stat_pwm        | \[15\]    | ro   | —     | ~o_rst_pwm_n            |
| stat_gpio1      | \[16\]    | ro   | —     | ~o_rst_gpio1_n          |
| stat_gpio2      | \[17\]    | ro   | —     | ~o_rst_gpio2_n          |
| reserved        | \[30:18\] | ro   | 0x0   | Read as zero.           |
| stat_cpu        | \[31\]    | ro   | —     | ~o_rst_cpu_n            |

Table 6‑3. DOMAIN_RST_STATUS fields

ro fields driven by hardware have no stored reset value; the value read is the live input. Software running on Ibex always reads stat_cpu = 0 (the CPU is running); the bit is useful to SYSDBG, which reads SYSCSR through S_BUS while it holds the CPU in reset.

### CHIP_ID_REV (0x0008)

| Bit name | Bits | Type | Reset | Description |
|:---|:---|:---|:---|:---|
| chip_id_rev | \[31:0\] | ro | 0x51534F43 | ASCII 'QSOC' (0x51 'Q', 0x53 'S', 0x4F 'O', 0x43 'C'), tied off at integration. There is no separate revision field; a revision register will be added if one is needed. |

Table 6‑4. CHIP_ID_REV fields

## Integration

SoC-top connection of SYSCSR (illustration; port names as generated by APB-CSR-Generator):

> m_scrc_syscsr u_syscsr (
>
> .i_bus_clk (o_clk_pbus),
>
> .i_bus_rstn (o_rst_por_n), // POR only
>
> // APB slave from P_BUS APB_S1 ...
>
> .i_protect_en (1'b0),
>
> .i_slverr_en (1'b1),
>
> .i_hw_we_resetcause_cause_por (1'b0), // reset value = 1
>
> .i_hw_wdata_resetcause_cause_por (1'b1),
>
> .i_hw_we_resetcause_cause_wdt (o_cause_we_wdt),
>
> .i_hw_wdata_resetcause_cause_wdt (1'b1),
>
> .i_hw_we_resetcause_cause_soft (o_cause_we_sw),
>
> .i_hw_wdata_resetcause_cause_soft (1'b1),
>
> .i_domainrststatus_stat_sbus (~o_rst_sbus_n),
>
> // ... one line per domain, Table 6-3 ...
>
> .i_domainrststatus_stat_cpu (~o_rst_cpu_n),
>
> .i_chipidrev_chip_id_rev (32'h51534F43)
>
> );

o_cause_we_wdt and o_cause_we_sw come from RRC, which runs on the SCRC internal clock. That clock and o_clk_pbus come from the same root through always-on gates, so the pulses are synchronous to i_bus_clk and need no synchronizer.

## Software Usage

- At start-up, read RESET_CAUSE, record it, then write back the value read to clear the bits that were set (write 1 to clear).

- After writing SOFT_RST_CTRL\[n\] in SCRC CSR, poll DOMAIN_RST_STATUS\[n\] until it reaches the requested state. Enable the domain clock (CLK_EN\[n\] = 1) before releasing its soft reset, otherwise the bit stays 1.

- CHIP_ID_REV can be used by the PC tools and by the debugger to check that they are connected to a QSOC.

## Workbook and Generation Notes

- The workbook must be regenerated for v2.0. The generated m_scrc_syscsr.sv currently in repo implement/APB-CSR-Generator/RTL/ is from v1 and is stale.

- Field changes against v1: stat_sysbus → stat_sbus, stat_perbus → stat_pbus, stat_gpio → stat_gpio0; new fields stat_sysdbg \[14\], stat_pwm \[15\], stat_gpio1..2 \[17:16\], stat_cpu \[31\]; cause_por reset value 0x0 → 0x1.

- Do not hand-edit the generated RTL: change the workbook and run CSR_Generation.py again.

## Verification Requirements

| ID | Requirement |
|:---|:---|
| SYSCSR_001 | After POR, RESET_CAUSE = 0x1, CHIP_ID_REV = 0x51534F43. |
| SYSCSR_002 | A watchdog reset sets cause_wdt and leaves every other RESET_CAUSE bit unchanged. |
| SYSCSR_003 | A software reset (SW_RST) sets cause_soft and leaves every other bit unchanged. |
| SYSCSR_004 | Writing 1 to a RESET_CAUSE bit clears only that bit; writing 0 has no effect. |
| SYSCSR_005 | DOMAIN_RST_STATUS\[n\] equals ~o_rst\_\<n\>\_n in every cycle, for all 19 status bits. |
| SYSCSR_006 | Writes to DOMAIN_RST_STATUS and CHIP_ID_REV do not change them. |
| SYSCSR_007 | With i_slverr_en = 1, a misaligned access or a partial-strobe write returns PSLVERR; an unused offset reads 0 and a write to it has no effect. |

Table 10‑1. Verification requirements

## Acronyms

| Acronyms | Description                                        |
|:---------|:---------------------------------------------------|
| APB      | Advanced Peripheral Bus                            |
| CSR      | Control and Status Register                        |
| POR      | Power-On Reset                                     |
| RRC      | Reset Request Controller (in SCRC)                 |
| SCRC     | System Clock & Reset Controller                    |
| SYSCSR   | System Control and Status Registers (status block) |
| W1C      | Write 1 to Clear                                   |
| WDT      | Watchdog Timer                                     |

## First Review

| Comment | Reviewer | Response |
|:---|:---|:---|
| CHIP_ID_REV constant misspelled 'QCOS'; the separate REV field was also left in one table. | Sinh | Accepted (V1.1): 0x51534F43 'QSOC' everywhere, no REV field. |
| MRV_BUSY status bit was premature. | Sinh | Accepted (V1.1): removed; not needed in V2.0 because SCRC uses polling. |
| RESET_CAUSE must survive WDT/SW resets. | Nam (SCRC v2 review) | Accepted (V2.0): SYSCSR reset = o_rst_por_n; cause_por reset value 1. |
| SYSDBG reads SYSCSR through S_BUS while the CPU is held (debug boot). | SYSDBG MAS V3.0 | Accepted (V2.1): stat_cpu at bit 31 is final. |
| GPIO3 removed (40-pin package, GPIO MAS V1.2). | GPIO owner | Accepted (V2.1): bit 18 reserved. |
