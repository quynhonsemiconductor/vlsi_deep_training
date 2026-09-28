# CPU -- design decisions

Reasoning, rejected designs and the history behind numbers in
[`QNSC_CPU_MAS.md`](QNSC_CPU_MAS.md). The MAS states what is true; this file
states why.

## One CPU2AXI bridge, not one per interface

Ibex exposes two independent memory-style ports (instruction, data). S_BUS is
an AXI4 crossbar with one slave port per master, not two, so something has to
merge them before reaching `AXI_S1`. The alternative -- one bridge per
interface, consuming two S_BUS slave ports -- was considered and rejected: it
would cost an extra crossbar port for no benefit, since `axi_mux`'s
round-robin arbitration already resolves simultaneous instruction and data
requests correctly with a single merged port, and one shared bridge means one
port index folded into the AXI ID is enough to keep responses distinguishable,
rather than needing a second, independent ID scheme.

## Leader's Ibex parameter review (2026-09-28)

A lead-engineer review walked all 35 `ibex_top` parameters against the
"general-purpose small MCU" configuration this project targets. 32 rows were
confirmed already correct as configured. Three were changed:

- **`DbgTriggerEn`: 0 -> 1.** Enables the hardware-trigger CSRs the two
  breakpoints below need. With it left at 0, `DbgHwBreakNum` has nothing to
  attach to.
- **`DbgHwBreakNum`: 1 -> 2.** Two hardware breakpoints are materially more
  useful for GDB/OpenOCD firmware debugging than one, and -- unlike a software
  `ebreak` -- a hardware breakpoint needs no write into instruction memory to
  fire, so it also works in code that cannot be modified, such as the ROM
  bootloader.
- **`CsrMimpId`: 0 -> 1.** `mimpid` is implementation-defined; there is no
  registration requirement the way there is for `mvendorid` (a JEDEC JEP106
  manufacturer code QSOC cannot legally claim). Setting it to a real,
  non-default value lets firmware distinguish this specific core
  implementation/revision, at zero hardware cost.

`util/qsoc_contract.yml` is not where these three values live -- they are
pure `ibex_top` build-time parameters, not numbers shared across blocks, so
they are set directly in `m_qnsc_wrap_ibex.src.sv` rather than imported from
`qnsc_pkg`.

## The debug-boot address bug (found 2026-09-28)

While applying the review above, `m_qnsc_wrap_cpu`'s boot-address mux was
found to point debug boot at `qnsc_pkg::C_ISRAM_DBG_BASE` (`0x2000_0000`, the
4 KiB debug/DM window) instead of `qnsc_pkg::C_ISRAM_BASE` (`0x2000_1000`, the
downloaded-application region). Both are valid, real contract constants --
`hardcode_check.py`'s job is exactly "is this a contract constant", not "is it
the *correct* contract constant for this call site" -- so no automated check
flagged it. It surfaced only by reading `QNSC_ROM_MAS` (which states plainly
that debug boot's first fetch is at `0x2000_1080`) side by side with this
block's own boot-address logic, and confirming against the already-ratified
QSOC HAS report, which independently states the same address. The fix:
`P_BOOT_ADDR_DBG` now reads `qnsc_pkg::C_ISRAM_BASE`.

The general lesson, not specific to this bug: a hardcode-check style
automated tool can confirm a literal *is* an agreed constant; it cannot
confirm it is the *right* constant for that specific use, when more than one
constant is a legal match at the type level. That check still has to be done
by a person holding both specs at once.
