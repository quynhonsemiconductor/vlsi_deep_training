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
they are set directly in `m_qnsc_wrap_cpu_ibex.src.sv` rather than imported from
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
QSOC HAS report, which independently states the same address. The fix, at the
time: the wrapper's own `P_BOOT_ADDR_DBG` localparam changed from
`qnsc_pkg::C_ISRAM_DBG_BASE` to `qnsc_pkg::C_ISRAM_BASE`. That localparam and
its internal mux no longer exist -- see the next section.

The general lesson, not specific to this bug: a hardcode-check style
automated tool can confirm a literal *is* an agreed constant; it cannot
confirm it is the *right* constant for that specific use, when more than one
constant is a legal match at the type level. That check still has to be done
by a person holding both specs at once.

## Moving qnsc_pkg out of the wrapper (2026-09-28, #35)

A rule change (`chore/ip-integration-rules`, #35) settled a review comment on
another block's wrapper: IP does not import `qnsc_pkg` or reference it
directly -- design/top ties any chip-decided value in on an `i_cfg_*` port,
and a structural value that must equal the contract carries a
`// contract: <key>` tag instead (design/README.md, "Shared numbers: who may
use `qnsc_pkg`"). `cpu` is IP, and `m_qnsc_wrap_cpu.src.sv` used both patterns
the rule now forbids:

- The boot-address mux above (`w_boot_addr = i_dbg_en ? qnsc_pkg::C_ISRAM_BASE
  : 32'h0`) computed a chip value from `qnsc_pkg` inside the wrapper. Fixed by
  deleting the mux and the `import qnsc_pkg::*;` it needed, and taking the
  already-resolved value on a new `i_cfg_boot_addr` port instead -- exactly
  how Ibex itself already takes `boot_addr_i`. `i_dbg_en` no longer has a
  reason to be a `cpu` port; the mux and the debug-enable signal both move to
  whichever integration block computes `i_cfg_boot_addr` (design/top).
- `P_HART_ID` was a module parameter, which the rule also forbids ("a wrapper
  has no parameter"; an empty `#()` is what's accepted). Hart id is one of the
  rule's own worked examples of an `i_cfg_*` value, so it became
  `i_cfg_hart_id`, tied by design/top (`32'h0` while QSOC has one core).
- `m_qnsc_wrap_cpu_ibex.src.sv`'s `DmBaseAddr`/`DmHaltAddr`/`DmExceptionAddr`
  read `qnsc_pkg::C_ISRAM_DBG_BASE` directly. These are `ibex_top`
  *parameters*, not ports, so they cannot become `i_cfg_*` ports (a parameter
  is elaboration-time, not a runtime connection) -- they took the rule's other
  path instead, a fixed value tagged `// contract: memory_map.isram_dbg.base`,
  which `contract_tag.py` checks against `util/qsoc_contract.yml` on every
  run.
- Removing `import ibex_pkg::*;`/`import cpu2axi_pkg::*;` (module_rules.py's
  NO-IMPORT: an emacs-expanded file has no import at all, regardless of which
  package) surfaced one more real AUTOINPUT gap: `ibex_top`'s own
  `cheriot_enable_i`/`fetch_enable_i`/`mcounteren_writable_i`/`crash_dump_o`/
  `lockstep_cmp_en_o` are typed `ibex_mubi_t`/`crash_dump_t`, bare names that
  only resolved before because `ibex_top` carries its own `import
  ibex_pkg::*;` -- copied verbatim by AUTOINPUT into a wrapper with no import
  of its own. Fixed in `fixup_ibex_wrap.py` by qualifying them
  `ibex_pkg::ibex_mubi_t`/`ibex_pkg::crash_dump_t` where they're declared,
  which needs no import.
- `m_qnsc_wrap_cpu_ibex`/`m_qnsc_wrap_cpu_cpu2axi` (this block's two internal
  sub-boundaries, composed by `m_qnsc_wrap_cpu`) were renamed from
  `m_qnsc_wrap_ibex`/`m_qnsc_wrap_cpu2axi` to satisfy module_rules.py's
  WRAP-NAME check: a wrapper in `design/cpu` is `m_qnsc_wrap_cpu` or
  `m_qnsc_wrap_cpu_<variant>`, and these are the block's own variant naming
  for its two sub-boundaries, not a separate block.
