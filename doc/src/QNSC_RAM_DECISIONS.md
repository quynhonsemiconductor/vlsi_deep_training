# QNSC_RAM — design decisions and record

**This is not the specification.** That is
[`QNSC_RAM_MAS.md`](QNSC_RAM_MAS.md).

This file is the V1.9 document as it stood before that rewrite, kept whole: the
revision history, the memory map as it was proposed and argued before
`util/qsoc_contract.yml` became the authority, the reasoning behind each
parameter, the observations, and how every open question closed.

Nothing here was deleted from the specification without being kept here first.

---

# Reversion and History

| Version | Date       | Author/Owner | Description of Change |
|---------|------------|--------------|-----------------------|
| V1.0    | 2026-09-16 | Nghia VT     | First issue as a standalone document. Supersedes the RAM half of `QNSC_RAM_Debugger_MAS` V1.2, which specified the RAM and the Debugger together. Content is unchanged from that issue: the controller is `nguyenquanicd/AXI4-SRAM-CONTROLLER`, with the `WSTRB` byte-enable path added for QSOC. |
| V1.1    | 2026-09-17 | Nghia VT     | Follows the instructor's ruling of 2026-09-17. The debug program is no longer a block of its own: it is the first 4 KiB of `ISRAM`. The RAM is now **two** instances -- `ISRAM` for the program and `DSRAM` for data -- because QSOC has no flash and the program runs from RAM. ROM reduced to 8 KiB by its owner. Memory map rewritten (Tables 10--14), decode windows and the Ibex reset-vector offset documented, and the `WSTRB` and `WRAP` findings traced through `pulp-platform/axi`. |
| V1.2    | 2026-09-17 | Nghia VT     | Adopts the memory map agreed with the CPU and bus owners: `ISRAM` at `0x2000_0000`, `DSRAM` at `0x3000_0000`, the APB window at `0x8000_0000`, and `DSRAM` moving to `AXI_M2` with `AXI2APB` to `AXI_M3` (Table 10). Decode windows narrowed to the memory actually present, with `DECERR` everywhere else (Table 12). The debug program is fixed at the **bottom** of `ISRAM` so the CPU's `Dm*` parameters do not move when `PARA_SRAM_DEPTH` changes. `ISRAM` confirmed at 64 KiB, with the firmware cost estimate that decided it added as Table 14. `PARA_ADDR_WD` corrected to `PARA_SRAM_DEPTH` where the text meant capacity. |
| V1.3    | 2026-09-18 | Nghia VT     | **Aligned with `QSOC_HAS`, the system architecture specification, after a line-by-line comparison.** The memory map needed no change: base addresses, sizes, the 4 KiB debug window at the bottom of `ISRAM`, the `ISRAM`/`DSRAM` split and the 16 APB slaves of 16 KiB all match the HAS exactly. **What was wrong was the boot flow.** V1.0--V1.2 assumed the application arrived **over JTAG** and that the ROM therefore "does very little: come out of reset, and wait", stating explicitly that a UART bootloader "would need more" ROM than QSOC has. Both the instructor's direction and `QSOC_HAS` say the opposite: the ROM holds a **serial bootloader** which receives a single header/payload/CRC32 frame over `UART0` at 115200 baud -- 2.0 s for a 22 KiB image, 5.4 s for a full 60 KiB -- and the **debug interface is the second load path**, used when the ROM contents themselves are suspect. The HAS budgets that bootloader at **1.1 KiB with a bitwise CRC32 or 2.1 KiB with a table**, so 8 KiB of ROM is ample *for a real bootloader* rather than ample because the ROM is nearly empty. Section 5.1 is rewritten accordingly: the conclusion that `ISRAM` needs 60 KiB free is unchanged, but the reason is now that the bootloader **puts** the program there. Two of the HAS's ROM budget items belong to this document and are cross-referenced: the 128-byte trap vector table is the ROM layout of Table 15, and the payload copy loop is the only master that writes `ISRAM` before the application exists. |
| V1.4    | 2026-09-18 | Nghia VT     | **Adds the clock and reset domain, which this document had never stated, and closes an open row in `QSOC_HAS` that named it.** New section 5.2. `QSOC_HAS` Table 4-2 puts `ISRAM` and `DSRAM` in one domain, **`D13`**, sharing **soft-reset bit 12** and one clock gate, with the ROM separate in `D12`. Sharing one bit has a consequence now recorded: a soft reset of `D13` resets the memory holding the code that issued the write, so firmware running from `ISRAM` cannot reset the RAM domain and survive -- safe only from ROM. **The boot-memory ordering row that `QSOC_HAS` left TBD is answered from the AXI specification rather than by simulation.** The HAS records two readings of a fetch issued while the memory is still in reset: a stalled handshake, or undefined read data causing a trap. **The second cannot happen** -- AXI requires every `VALID` to be deasserted during reset, so a slave in reset cannot assert `rvalid` and there is no read data to be undefined. The core simply waits, so ordering is **not** a correctness requirement and the clock-and-reset specification is right that no sequencing is needed. What replaces it is a **liveness** problem worth more attention: AXI has no timeout, so a core waiting on a memory that never leaves reset waits forever with no exception and nothing in any status register, and the only block that can observe it is `SYSDBG`, which sits outside the `ndmreset` fan-out. Also fixes a duplicated section number -- Open questions was 5.3 twice -- and the cross-reference that pointed at it. |
| V1.5    | 2026-09-18 | Nghia VT     | Cross-checked against `QSOC_HAS` EN v1.1, which surfaced a gap this document had: nothing was said about the SRAM macro's **non-functional pins**. Section 4.8 now requires margin, retention and test to be tied to their databook defaults, and explains why a specification has to say so -- the behavioural model has no such pins, so no simulation can fail because of them. The memory map, the ISRAM split and the boot flow all still agree line for line. Section 5.2 signs off the shared `D13` domain that the HAS puts to this author as an open item, and records the reserved `SOFT_RST_CTRL` bits `[15:14]` as the escape hatch that keeps the decision reversible |
| V1.6    | 2026-09-21 | Nghia VT     | **ROM resized from 8 KiB to 2 KiB** and the bootloader budget rewritten, following the Day005 review of 2026-09-18, which fixed ROM at 2 KiB with the program inside it at **not more than 1 KiB**; the ROM owner's specification agrees, decoding 11 bits for 512 words. Section 5.1 now shows what is actually left -- **128 B** of forced vector table and **1920 B** of usable space -- and draws the consequence the earlier text could not: the **2.1 KiB table-driven CRC32 no longer fits**, so the bitwise variant is required. The memory map, the decode window and the FPGA block counts are updated. `ISRAM` and `DSRAM` are unchanged at 64 KiB and 32 KiB. |
| V1.7    | 2026-09-21 | Nghia VT     | Three open questions resolved. The **`WSTRB` addition is claimed** by this author, since it lives in the wrapper rather than inside the IP. And the licensing and `WRAP`-reporting questions both become one question to the mentor: `nguyenquanicd/AXI4-SRAM-CONTROLLER` is **the mentor's own repository**, the same account supplying `APB-CSR-Generator`, `APB-BUS-Generator`, `FirstX2P` and `MRV-CPU` to QSOC -- so the `WRAP` finding reaches its author directly and benefits ROM as well. |
| V1.8    | 2026-09-21 | Nghia VT     | **The open-question list is emptied of everything that did not need someone else.** Item 1 closes: the ROM owner's specification confirms the bootloader is theirs at **2 KiB / <= 1 KiB**, and the boot flow specification confirms `boot_addr_i` with Ibex fetching from `0x0000_0080`. Item 3 closes as **out of scope for v1**, with the real cost named -- scrambling changes the read path rather than adding a module. The licensing and `WRAP`-reporting items are reclassified as **action items**, since they are things to do rather than information to wait for, and both go to the mentor whose repository the IP is. |
| V1.9    | 2026-09-21 | Nghia VT     | Corrects a **stale cross-reference**: section 5.2 argued that `SYSDBG` could observe a stuck memory reset because it sat outside the `ndmreset` fan-out, but `QNSC_SYSDBG_MAS` **removed `ndmreset` at V1.9** following the Day005 reset-source decision. The observation still holds for a different reason -- `SYSDBG` is in domain `D15`, released before the CPU -- but the conclusion is now **stronger**: the debugger can see a stuck reset and cannot clear it, so recovery is a power cycle and the liveness guarantee is owed by the clock and reset owner. |

# Table of Tables

| Table | Title |
|-------|-------|
| Table 1 | IP sourcing decision |
| Table 2 | RAM controller sub-modules |
| Table 3 | AXI interface signals present and absent |
| Table 4 | FIFO buffers |
| Table 5 | Where the byte enables are lost |
| Table 6 | Closing the byte-enable gap: three options |
| Table 7 | Burst address generation |
| Table 8 | RAM configuration parameters |
| Table 9 | Verification QSOC must add |
| Table 10 | QSOC memory map |
| Table 11 | What splitting the RAM removes, with one `CPU2AXI` |
| Table 12 | Decode window against memory actually present |
| Table 13 | Where the debug memory can live |
| Table 14 | Estimated `ISRAM` occupancy for QSOC's peripheral set |
| Table 15 | ROM layout forced by the Ibex reset vector |
| Table 16 | Interfaces to agree with the team |
| Table 17 | Acronyms |

# Table of Figures

| Figure | Title |
|--------|-------|
| Figure 1 | Where the RAM sits in QSOC |
| Figure 2 | The AXI4 SRAM controller and its macro |

---

# 1. Overview

## 1.1 Scope

This document specifies the **RAM** of **QSOC**, the MCU built in this training
project. In the QSOC block diagram it is **two** slaves: `ISRAM` on `AXI_M1`,
holding the program, and `DSRAM` on `AXI_M2`, holding data. Both are the same
controller with a different macro depth, so one specification covers both --
section 5.1 explains why the block diagram was split.

The debugger, `SYSDBG`, is the author's second block and is specified separately
in `QNSC_SYSDBG_MAS`. The two are described apart because they are different
kinds of work: the RAM is an **integration** of an existing IP, while `SYSDBG` is
an **in-house design**. They meet only on `S_BUS`, where the debugger is one of
the masters this block must serve.

QSOC uses **AXI** for the system bus (`S_BUS`) and **APB** for peripherals
(`P_BUS`). The IP selected here is therefore a native AXI4 slave, not an adapted
one.

**Table 1 -- IP sourcing decision**

| Item | Source | License | Why this one |
|---|---|---|---|
| RAM controller | [`nguyenquanicd/AXI4-SRAM-CONTROLLER`](https://github.com/nguyenquanicd/AXI4-SRAM-CONTROLLER), `rtl/m_vlsi_axi4_sram.sv` and four sub-modules | **None declared** -- see 5.3 | Native **AXI4 full** slave with burst support, written in SystemVerilog, with a 46-test directed regression already in the repository. It speaks AXI on one side and a plain SRAM interface on the other, which is exactly the shape QSOC needs. |
| RAM macro | Technology-dependent; `sim/vcs/env/m_vlsi_sram_sp.sv` in the same repository is the behavioural model | n/a | Single-port SRAM with a one-cycle read latency. Replaced by a real macro or an FPGA block RAM at implementation time. |
| Byte-enable path | **Designed in house** -- section 4.4 | n/a -- own RTL | The controller has no `WSTRB` path. A RISC-V core executing `sb` or `sh` requires one. |

**What changed from the earlier issue.** The first version of this specification
paired an AXI front-end from `verilog-axi` with OpenTitan's scrambling and SECDED
primitives -- sound, but an assembly of three sources, and it made the RAM a
security exercise before it was a working memory. `AXI4-SRAM-CONTROLLER` is a
single coherent IP that does the one thing QSOC needs first: terminate AXI4 and
drive an SRAM.

## 1.2 Position in the system

![Figure 1 -- Where the RAM sits in QSOC](../img/fig_qsoc_mem.png){width=6.4in}

Three blocks issue transactions on `S_BUS`: `CPU2AXI` on `AXI_S1`, `SYSDBG` on
`AXI_S0`, and `DMA` on `AXI_S2`. Three memories answer them: `ROM` on `AXI_M0`,
`ISRAM` on `AXI_M1` and `DSRAM` on `AXI_M2`. Peripherals sit behind the
`AXI2APB` bridge on `AXI_M3`.

Two consequences for this specification:

1. The RAM must tolerate **three independent masters**. Arbitration between them
   is the bus's responsibility, not the RAM's, but the RAM must not assume a
   single requester -- and the round-robin arbiter of section 4.1 arbitrates only
   between this block's own read and write paths, which is a different question.
2. One of those masters is the **debugger**, which reads and writes the RAM
   without the CPU being involved. That is how firmware is loaded, and it means
   accesses can arrive while the CPU is halted or while it is running.

**The same controller is instantiated three times in QSOC** -- `ISRAM` and
`DSRAM` here, and the `ROM` by its own owner. A ROM is never written, so the
`WSTRB` gap of section 4.4 does not apply to it, and the block is used there
unmodified.

# 2. Feature

## 2.1 Feature -- RAM

The RAM block is an **AXI4 SRAM controller** plus a memory macro. The controller
is taken as an IP; the macro is technology-dependent and is chosen at
implementation time.

**Provided by the IP:**

- **Native AXI4 (full) slave**, not AXI4-Lite: independent read and write
  channels, each with its own address FSM.
- **Burst transfers**, `AxLEN` from 0 (single) to 255 (256 beats), with `INCR`
  and `FIXED` burst types. See section 4.6 on `WRAP`.
- **AXI ID preserved end to end**, `AWID` to `BID` and `ARID` to `RID`, at a
  configurable width. Transactions are not reordered.
- **Five FIFOs**, one per AXI channel, so AXI handshaking is decoupled from SRAM
  access timing and back-to-back transfers do not stall.
- **Round-robin arbitration** between the read and write paths into the single
  SRAM port, so neither can starve the other.
- **Configurable** data width, address width, ID width and FIFO depth.

**Added for QSOC, section 4.4:**

- A **`WSTRB` byte-enable path**, without which a RISC-V `sb` or `sh` would
  destroy the rest of the word.

**Deliberately not in this issue:** data scrambling, address scrambling and
SECDED integrity, so that a working memory comes first. Section 5.3 records what
adding them would cost.

**Not implemented by the IP, and out of scope:** exclusive access, locked
transfers, narrow transfers (`AxSIZE` is not a port -- the transfer size is fixed
at the data width), and error responses (`BRESP` and `RRESP` are hardwired to
`OKAY`).

# 3. Block Diagram

![Figure 2 -- The AXI4 SRAM controller and its macro](../img/fig_ram_simple.png){width=6.5in}

# 4. Micro-architecture Details

## 4.1 Structure

Figure 2 shows the controller. It is five modules, and all five are IP -- the
only RTL QSOC adds is the byte-enable path of section 4.4.

**Table 2 -- RAM controller sub-modules**

| Module | Role |
|---|---|
| `m_vlsi_axi4_sram` | Top level. Instantiates and wires everything below |
| `m_vlsi_axfsm` | AXI address FSM. Two instances, one for `AW` and one for `AR`. Handles the address handshake, generates one address per burst beat, and pushes address, ID and a last-beat flag into a FIFO |
| `m_vlsi_fifo` | Parameterised synchronous FIFO. Five instances. Full and empty are detected with an extra pointer MSB |
| `m_vlsi_arbiter` | Round-robin arbiter between the read and write requests for the single SRAM port |
| `m_vlsi_sram_misc` | Control and datapath glue: FIFO pop logic, the SRAM address and data mux, and generation of the `R` and `B` responses |

Each address FSM has two states. `S_IDLE` waits for `AxVALID` and `AxREADY`;
`S_ADDR` emits one beat per cycle for as long as the downstream FIFO can accept
one. `AxREADY` is combinational, asserted when the FSM is idle **and** the FIFO
is not full, so a handshake never promises a beat the FIFO cannot take.

## 4.2 The AXI interface, and what is absent from it

Reading the port list is the fastest way to understand this block's scope. The
top module has **33 ports**, and the absences matter as much as the presences.

**Table 3 -- AXI interface signals present and absent**

| Channel | Present | Absent |
|---|---|---|
| `AW` | `awaddr`, `awvalid`, `awready`, `awburst`, `awlen`, `awid` | `awsize`, `awprot`, `awcache`, `awlock`, `awqos` |
| `W` | `wdata`, `wvalid`, `wready`, `wlast` | **`wstrb`** |
| `B` | `bid`, `bresp`, `bvalid`, `bready` | -- |
| `AR` | `araddr`, `arvalid`, `arready`, `arburst`, `arlen`, `arid` | `arsize`, and the same qualifiers as `AW` |
| `R` | `rid`, `rdata`, `rresp`, `rvalid`, `rlast`, `rready` | -- |
| SRAM | `sram_addr`, `sram_wdata`, `sram_we`, `sram_oe`, `sram_rdata` | byte write enables |

Three consequences follow, and each is addressed below: there is no byte-enable
path (4.4), the transfer size is fixed at the data width because `AxSIZE` is not
read (4.5), and `BRESP` and `RRESP` are tied to `OKAY` so the RAM never reports
an error (4.7).

`i_wlast` is in the port list but is not used internally -- the last beat is
tracked by the address FSM's own counter, not by the master's flag.

## 4.3 FIFOs and flow control

**Table 4 -- FIFO buffers**

| FIFO | Width | Contents |
|---|---|---|
| `AWFIFO` | `ADDR + ID + 1` | write address, ID, last flag |
| `WFIFO` | `DATA` | write data |
| `ARFIFO` | `ADDR + ID + 1` | read address, ID, last flag |
| `RFIFO` | `DATA + ID + 2 + 1` | read data, ID, `RRESP`, last flag |
| `BFIFO` | `ID + 2` | ID, `BRESP` |

All five share one depth, `PARA_FIFO_DEPTH`. Every `READY` on the AXI side is
derived from FIFO occupancy -- `o_wready = ~wfifo_full` is the clearest case -- so
back-pressure propagates naturally and no timer or counter is involved.

A write is executed when the arbiter grants and **both** `AWFIFO` and `WFIFO` are
non-empty; the two are popped together. When the popped entry carries the last
flag, a `BRESP` entry is pushed into `BFIFO`.

A read is issued when `ARFIFO` is non-empty, `RFIFO` is not full, and no read is
already pending. **Only one SRAM read is in flight at a time** (`reg_rd_pending`
in `m_vlsi_sram_misc`): the address is presented in one cycle and the data is
captured and pushed into `RFIFO` in the next. This costs read throughput -- a
burst read cannot issue a new address every cycle -- and is the first thing to
revisit if the RAM becomes a bottleneck.

## 4.4 The byte-enable path -- what QSOC must add

**This is the one functional gap, and it is the RTL this project contributes.**

The controller has no `WSTRB` input and the SRAM interface has no byte write
enables, so every write is full width. That is a stated design boundary of the
IP, not a defect -- its README says so plainly -- and for **ROM it does not matter
at all**, since a ROM is never written.

For RAM it matters, because RV32 has `sb` and `sh`. Any C code touching a
`uint8_t`, a packed struct field, or a string will emit them. Today such a store
would write the whole 32-bit word and destroy the three bytes beside the one the
program meant to change -- silently, with no error response.

**The byte-enable information does reach this block; it is dropped here and
nowhere earlier.** The chain is intact the whole way, which is worth checking
rather than assuming:

**Table 5 -- Where the byte enables are lost**

| Stage | Signal | Present |
|---|---|---|
| Ibex core | `data_be_o`, 4 bit | yes (`ibex_top.sv`) |
| `CPU2AXI` -- a wrapper merging `instr_*` and `data_*`, over `axi_from_mem` | `mem_be_i`, 4 bit, becomes AXI `wstrb` | yes, provided the merge carries it |
| `S_BUS` -- `axi_xbar` | `wstrb` carried | yes |
| **This controller** | **no `wstrb` port at all** | **no** |

So the strobes arrive at the RAM's door and are discarded there. Adding the port
is not compensating for something missing upstream -- it is connecting the last
link of a chain that is otherwise complete.

Three ways to close it. The third is what this specification proposes.

**Table 6 -- Closing the byte-enable gap: three options**

| Option | Cost | Verdict |
|---|---|---|
| Constrain firmware to word accesses only | No RTL, but it constrains every future line of C and cannot be enforced | Not viable |
| Read-modify-write inside the controller | No macro change, but every sub-word write becomes read then write, and it must be interlocked against reads to the same address | Viable, but slower and easy to get wrong |
| **Carry `WSTRB` through to byte write enables** | `i_wstrb` added to the port list and to `WFIFO`, passed to the macro as `o_sram_be` | **Proposed.** It is what the AXI protocol intends, and one cycle per write |

The change is small and localised: widen `WFIFO` by `DATA/8` bits, add the port,
and require a macro with byte write enables. FPGA block RAM and every standard
SRAM compiler offer them.

## 4.5 Burst address generation

Each address FSM registers the address, the burst type, the ID and a beat count
on the handshake, then produces one address per beat.

**Table 7 -- Burst address generation**

| Burst type | Next address |
|---|---|
| `FIXED` (`00`) | unchanged |
| `INCR` (`01`) | `addr + DATA_WD/8` |
| `WRAP` (`10`) | see 4.6 |

The increment is **hardwired to the full data width**. `AxSIZE` is not a port, so
a master requesting a narrower transfer is not refused -- it is simply ignored,
and the addresses advance by four bytes regardless. QSOC must therefore treat the
transfer size as fixed at 32 bits.

Addresses must be aligned to the data width. The stride is a constant, so an
unaligned start address stays unaligned for the whole burst.

**Address width at the macro.** `o_sram_addr` is a **byte** address. A real macro
is word-addressed, so the integration connects `o_sram_addr[ADDR-1:2]`. The
behavioural model in the IP's simulation environment indexes with the byte
address directly, which is harmless in simulation but is not how a macro is
wired.

## 4.6 WRAP: a finding, and the constraint it implies

**`WRAP` is declared as supported but is not implemented.** The calculation is

```systemverilog
// m_vlsi_axfsm.sv
assign addr_wrap = (reg_axaddr + PARA_BYTE_COUNT) & ~(PARA_BYTE_COUNT - 1);
```

With a 32-bit data width `PARA_BYTE_COUNT` is 4, so the mask clears the low two
address bits. That **aligns** the address; it does not wrap it. A correct `WRAP`
returns to the start of a block of `(AxLEN + 1) x size` bytes, which requires
`AxLEN` to be retained -- and the FSM keeps only a down-counter, not the length.
For an aligned start address, `WRAP` is therefore identical to `INCR`.

The IP's own regression does not catch this because its reference model computes
the same thing:

```systemverilog
// sim/vcs/env/axi_svt_basic_env.sv
default: next_addr = (curr_addr + 4) & 32'hFFFF_FFFC;
```

The four `wrap_*` tests pass because the checker agrees with the design under
test, not because the addresses are right. This is recorded here because it is
the kind of agreement that a passing regression cannot reveal, and because the
finding should go back to the IP's authors.

**Consequence for QSOC: none in practice, and there is a ready mitigation if
that ever changes.**

`WRAP` exists for cache line fills with critical-word-first ordering. Nothing in
QSOC issues one today, and two of the three masters cannot:

- **The CPU path issues no bursts at all.** `axi_from_mem`, the module in
  `pulp-platform/axi` that converts Ibex's memory interface to AXI, emits
  single-beat transactions. A burst of any kind, let alone a wrapping one, never
  reaches the bus from the CPU.
- **`SYSDBG` issues AXI4-Lite single beats**, which have no burst type.
- The **DMA** is the one master that could in principle issue a `WRAP`, and that
  is a question for its owner.

If a wrapping burst ever does appear, the fix needs no change to this IP:
**`axi_burst_unwrap.sv`**, in the same `pulp-platform/axi` library already chosen
for `S_BUS`, *"splits wrapping AXI4 bursts into incremental bursts"*. Placing it
in front of this controller converts the one burst type it gets wrong into the one
it gets right.

The constraint should nonetheless be written down, and belongs in the integration
checklist of section 5.3.

## 4.7 Error handling

`BRESP` and `RRESP` are always `2'b00` (`OKAY`). The value is not tied off at the
port -- both are read out of their response FIFOs -- but the constant `2'b00` is
what `m_vlsi_sram_misc` pushes in, so the RAM can never report a `SLVERR` or a
`DECERR`. Two consequences:

1. **An out-of-range address is not refused.** Address decoding is the bus's
   responsibility; anything reaching this block is assumed to be in range. The
   `S_BUS` decoder must therefore return `DECERR` itself for unmapped addresses,
   rather than routing them here.
2. **There is no error detection in the memory.** Without SECDED there is nothing
   to report, so the tie-off is consistent with the current scope rather than a
   shortcut. If integrity is added later (5.3), `RRESP` becomes a real signal and
   `RFIFO` already carries the two bits for it.

## 4.8 Configuration parameters

**Table 8 -- RAM configuration parameters**

| Parameter | Default | Meaning | `ISRAM` | `DSRAM` |
|---|---:|---|---|---|
| `PARA_DATA_WD` | 32 | Data width in bits | 32 | 32 |
| `PARA_ADDR_WD` | 32 | Address width in bits | 32 | 32 |
| `PARA_ID_WD` | 4 | AXI ID width -- set by the `S_BUS` interconnect, which widens master IDs to keep them unique | same | same |
| `PARA_LEN_WD` | 8 | `AxLEN` width, 8 gives 256 beats | 8 | 8 |
| `PARA_FIFO_DEPTH` | 8 | Depth of all five FIFOs, a power of two | 8 | 8 |
| `PARA_SRAM_DEPTH` | 1024 | **Not a controller parameter** -- it belongs to the SRAM macro, `sim/vcs/env/m_vlsi_sram_sp.sv` line 13. It is the only thing that sets how much memory is present | 16384 words, 64 KiB | 8192 words, 32 KiB |

**The two instances differ in one thing only: the depth of the macro behind
them.** Every controller parameter is identical, `PARA_ADDR_WD` included -- it is
the width of the AXI address bus, 32 bits for both, not a statement about how much
memory is present. The size comes from `PARA_SRAM_DEPTH` on the macro, so changing
either RAM's capacity is a **one-parameter edit with no RTL change**; what it does
change outside this block is the decode window the interconnect hands to that
slave, section 5.1.

`PARA_FIFO_DEPTH` sets all five FIFOs at once. Deeper FIFOs absorb longer bursts
without back-pressure and cost registers; there is no way to size the write path
and the read path differently without editing the top level.

**The real macro has pins the behavioural model does not, and they must not be left
to chance.** `m_vlsi_sram_sp.sv` is a simulation model with a functional port list
only. The SMIC 28nm macro that replaces it carries **margin, retention and test**
pins as well, and none of them are driven by the controller -- the controller does
not know they exist. `QSOC_HAS` puts the rule to this author and it is accepted
here: every pin the design does not use is tied to **the value its databook
recommends** rather than to whatever is convenient -- margin at its default level,
retention off, test off. The reason to write this down in a specification rather
than leave it to physical design is that all three of those pins are **harmless in
simulation and wrong only in silicon**: the behavioural model has no margin pin to
mis-drive, so no simulation can fail because of it, and a test pin left floating or
asserted is the kind of fault that appears as a memory that reads back its own
previous contents. It is recorded in the checklist of section 5.3 for that reason.

## 4.9 Verification available with the IP

The repository ships more verification than the RTL, and reusing it is part of
the reason for choosing this IP.

- **46 directed tests** driven by the Synopsys AXI VIP, covering bursts of every
  type and length, back-pressure, arbiter fairness and starvation, ID reuse and
  wrap-around, reset mid-burst, FIFO near-full, and long random soak runs.
- **Self-checking**, not just protocol-legal stimulus: the environment keeps a
  memory model and compares every read beat against it.
- **Lint scripts** for Synopsys VC Static and for Verilator.

Two qualifications. The testbench needs **VCS and a licensed Synopsys AXI VIP**;
without them the tests cannot be run as they stand, and Verilator lint is the only
part that runs on an open toolchain. And section 4.6 is a reminder that a
self-checking environment is only as correct as its reference model.

## 4.10 Verification QSOC must add

The regression above covers the IP as it stands. It cannot cover the byte-enable
path of section 4.4, because that path does not exist yet -- so those tests are
owed by this project.

**Table 9 -- Verification QSOC must add**

| What is checked | How |
|---|---|
| A byte store leaves the other three bytes of the word untouched | Write a known pattern to a word, then write one byte with `wstrb = 4'b0010`, then read the word back |
| All sixteen `wstrb` values, including `0000` and `1111` | Directed sweep at one address |
| A burst write where `wstrb` differs per beat | The strobes travel in `WFIFO` beside the data, so a per-beat difference is the case that catches a shared-register mistake |
| `wstrb` does not disturb reads | Read-after-write at the same address, with the read issued while a strobed write is still in the FIFOs |

The first of these is the acceptance test for the addition. It is also the
failure that would otherwise reach firmware as silent corruption, which is the
reason it is written down rather than left to a general soak test.

# 5. Integration into QSOC

## 5.1 A memory map to propose

The map below is the one **agreed with the CPU and bus owners**. Two of its
regions belong to the blocks specified here and a third is required by the
debugger, so the reasoning behind each line is recorded rather than left implicit.

**Table 10 -- QSOC memory map**

| Region | Base | Last address | Size | Bus port | Owner |
|---|---|---|---:|---|---|
| ROM, boot code | `0x0000_0000` | `0x0000_07FF` | **2 KiB** | `AXI_M0` | ROM owner |
| **Debug program**, first 4 KiB of `ISRAM` | `0x2000_0000` | `0x2000_0FFF` | 4 KiB | `AXI_M1` | this author |
| `ISRAM`, main program | `0x2000_1000` | `0x2000_FFFF` | 60 KiB | `AXI_M1` | this author |
| `DSRAM`, data | `0x3000_0000` | `0x3000_7FFF` | 32 KiB | `AXI_M2` | this author |
| APB peripherals behind `AXI2APB`, 16 slaves of 16 KiB | `0x8000_0000` | `0x8003_FFFF` | 256 KiB | `AXI_M3` | peripheral owners |
| `SYSDBG` registers | `0xF000_0000` | `0xF000_000B` | 12 B | **none -- JTAG only** | this author |
| Everything else | -- | -- | -- | `axi_err_slv`, `DECERR` | bus owner |

Two lines of that table are easy to misread and are worth spelling out.

**`SYSDBG`'s registers are deliberately not on the bus.** `0xF000_0000` is an
address in the JTAG command space only; `SYSDBG` decodes it internally and never
puts it on `S_BUS`. The interconnect must therefore leave that region
**unmapped**, answering `DECERR`. If the decoder claimed it as well, the register
would be shadowed by whatever slave won. `QNSC_SYSDBG_MAS` section 4.7 specifies
the registers themselves.

**Nothing at all is mapped between `0x8004_0000` and `0xFFFF_FFFF`,** nor in the
gaps between the regions above. Every one of those addresses answers `DECERR`.

**The RAM is two instances, not one.** QSOC has no flash, so the program lives in
RAM, and the instructor's direction is to split it: **`ISRAM`** holds
instructions -- both the debug program and the main program -- and **`DSRAM`**
holds data.

That split is worth more than the tidiness, and it is worth being precise about
what it does and does not buy, because `CPU2AXI` is **one** master port by
instruction -- Ibex's `instr_*` and `data_*` interfaces are merged by a wrapper
before they reach the bus.

`S_BUS` is a crossbar, so it serves several masters at once **as long as they
address different slaves**. With one RAM, every master queues for one slave port.
With two:

**Table 11 -- What splitting the RAM removes, with one `CPU2AXI`**

| While the CPU fetches from `ISRAM` | One RAM | `ISRAM` + `DSRAM` |
|---|---|---|
| the DMA moves a block | contend | **concurrent** |
| `SYSDBG` reads memory for the host | contend | **concurrent** |
| the CPU itself does a load or store | serialised at `CPU2AXI` | serialised at `CPU2AXI` |

So the split does not remove the CPU's own fetch-versus-data serialisation -- the
single wrapper decides that -- but it does remove contention between the CPU and
the two other masters. The DMA is precisely the master that moves large blocks
while the CPU runs, which is the case the split is worth having for.

It also removes the reason this author argued against putting the debug program
inside a RAM at all: a stray data pointer writes into `DSRAM`, and cannot reach
`ISRAM` unless it deliberately addresses that range.

**The debug program needs no hardware of its own.** It is the first 4 KiB of
`ISRAM` and nothing more -- an address convention. `SYSDBG` loads it there through
the AXI master it already has, and the main program's linker script starts at
`0x2000_1000`. The four `Dm*` parameters in `QNSC_SYSDBG_MAS` Table 11 follow
directly from `ISRAM`'s base.

**Why the debug program is at the *bottom* of `ISRAM` and not the top.** This
looks like an arbitrary choice and is not. The four `Dm*` parameters are
**compile-time parameters of `ibex_top`**, not registers: changing one means
re-elaborating the CPU. Put the 4 KiB at the top of `ISRAM` and its address is
`base + size - 0x1000`, so the day anyone changes `PARA_SRAM_DEPTH` -- the cheap,
expected edit of section 4.8 -- all four parameters move with it and the CPU has
to be rebuilt. Put it at the bottom and the parameters depend on the **base**
alone, which never moves; `ISRAM` grows upward into the reserved space above it
and nothing outside this block notices. The cost is that the main image starts at
`0x2000_1000` rather than `0x2000_0000`, which is one constant in a linker script.

**The size and the decode window are not the same thing, and the difference is
worth stating before anyone writes a decoder.** A decoder that selected each
region by `addr[31:28]` alone would hand every slave a whole nibble -- **256 MB**
-- while the memory actually behind it is kilobytes. The agreed map does not do
that. **Each window is narrowed to the memory actually present, and everything
else answers `DECERR`:**

**Table 12 -- Decode window against memory actually present**

| Region | Decode window handed to the slave | Memory actually present | Outside it |
|---|---|---:|---|
| ROM | `0x0000_0000` -- `0x0000_07FF` | **2 KiB** | `DECERR` |
| `ISRAM` | `0x2000_0000` -- `0x2000_FFFF` | 64 KiB, first 4 KiB the debug program | `DECERR` |
| `DSRAM` | `0x3000_0000` -- `0x3000_7FFF` | 32 KiB | `DECERR` |
| `AXI2APB` | `0x8000_0000` -- `0x8003_FFFF` | 16 APB slaves of 16 KiB | `DECERR` |

The alternative -- leaving each window a full nibble wide -- costs one comparison
less and is worse: an access to `0x2001_0000` beyond the macro depth would
**alias**, the bits above the depth silently dropped, and land back inside real
memory. A stray pointer would then read the wrong data with no indication that
anything had happened.

Narrowing needs **no new RTL**. `axi_err_slv.sv` in `pulp-platform/axi` -- the
library already chosen for `S_BUS` -- is exactly an error-responding slave, and
`axi_xbar`'s address rules take an explicit start and end per slave rather than a
mask. It is also what section 4.7 asks for, since this RAM answers `OKAY` to
every address it is given and cannot refuse one itself.

**The reserved space above each RAM is not wasted, it is the growth path.**
`0x2001_0000` -- `0x2FFF_FFFF` above `ISRAM` and `0x3000_8000` -- `0x3FFF_FFFF`
above `DSRAM` stay `DECERR` today. Enlarging either RAM means raising
`PARA_SRAM_DEPTH` and widening that slave's end address; because the debug
program sits at the **bottom** of `ISRAM`, no CPU parameter moves when `ISRAM`
grows.

**Where the debug program lives was put to the instructor, and the answer was to
keep it inside a RAM.** The reason a decision was needed at all is in
`QNSC_SYSDBG_MAS` section 4.11: when `debug_req` rises, Ibex jumps to
`DmHaltAddr` and fetches from it unconditionally, so something must answer at that
address from the very first bring-up, even while all it holds is a
spin loop.

Three options were put forward; the record is kept because the reasoning still
applies if the arrangement is ever revisited.

**Table 13 -- Where the debug memory can live**

| Option | Cost | Verdict |
|---|---|---|
| A. A dedicated 4 KiB block on its own slave port | One entry in the address decoder, one BRAM tile | Not taken |
| **B. Reserve the first 4 KiB of a RAM** | Nothing at all -- an address convention | **Chosen by the instructor.** The objection to it was that firmware could overwrite the debug program; splitting the RAM into `ISRAM` and `DSRAM` largely answers that, since data writes land in `DSRAM` |
| C. A wrapper behind `AXI_M1` that splits the port | Higher than A -- the `W` channel carries no address, so the wrapper must remember the `AW` routing until `WLAST` and track outstanding transactions, which is a second interconnect; and it adds a cycle to every SRAM read | Not taken |

**The slave-port count is the same either way, and that is worth stating plainly
so nobody re-opens the question expecting a saving.** Option A would have given
`S_BUS` four slaves -- ROM, SRAM, `AXI2APB`, debug. The arrangement actually
adopted also gives it four -- ROM, `ISRAM`, `DSRAM`, `AXI2APB`. What option B
avoids is a 4 KiB block of its own, not a port; what it buys is the separation of
instructions from data, which has value independent of debugging.

**Every region still has a distinct `addr[31:28]`,** even though the decoder
compares more than that nibble: ROM is `0x0`, `ISRAM` `0x2`, `DSRAM` `0x3`, the
APB window `0x8`, and the `SYSDBG` registers -- which never appear on the bus at
all -- `0xF`. Keeping the regions one nibble apart costs nothing and buys two
things: an address is recognisable at a glance while reading a trace, and the
coarse rule remains available to any block that only needs to know *which* region
an address is in. `SYSDBG` uses exactly that rule internally to separate its own
registers from everything it forwards to AXI (`QNSC_SYSDBG_MAS`, section 4.6).

**Why 64 KiB of `ISRAM` and 32 KiB of `DSRAM`.** 32 KiB of `ISRAM` was also on
the table and was rejected; the reasoning is recorded here because the figure is
a `PARA_SRAM_DEPTH` edit away from being changed again and whoever changes it
should know what the number was bought with.

1. **It has to hold the firmware, not just its data.** QSOC has **no flash**, so the
   application is **loaded into RAM after every reset and executed from RAM**. The
   load path is the **serial bootloader in ROM** -- `QSOC_HAS` specifies a single
   frame of header, payload and CRC32 over `UART0` at 115200 baud, which is 2.0 s
   for a 22 KiB image and 5.4 s for a full 60 KiB one. Those two figures are worth
   a note, because computing them from a nominal 115200 baud gives 5.3 s and makes
   them look wrong: the 20 MHz clock divides by 11, so the achieved rate is 113 636
   baud, 1.4 % low, and 60 KiB at ten bits per byte is 5.4 s at that rate. **The debug interface is the
   second load path**, used when the ROM contents themselves are suspect, and it is
   what makes the edit-load-run loop of `QNSC_SYSDBG_MAS` section 4.13 possible
   without re-running synthesis. Either way the program arrives in `ISRAM`, which is
   why `ISRAM` is the one that has to be generous:

   - the block diagram carries **both** a ROM and an SRAM, which only makes sense
     if they hold different things -- the ROM holds the bootloader, `ISRAM` holds
     what the bootloader receives;
   - on an FPGA a ROM is block RAM initialised by the bitstream, so changing its
     contents means re-running synthesis. That is acceptable for a bootloader that
     changes almost never, and unacceptable for an application under development,
     which is precisely why the application lives in RAM;
   - **the debug program shares `ISRAM` with the application**, taking its first
     4 KiB, so the space the application can use is 60 KiB and not 64.

   With the split, `ISRAM` carries all code -- the debug routine in its first 4 KiB
   and the main image after it -- while `DSRAM` carries only the stack, the heap and
   the globals.
2. **The peripheral list is fixed, so the firmware can be costed rather than
   guessed at.** QSOC carries **sixteen APB slaves**, but only **eleven distinct
   drivers** -- `GPIO0`--`GPIO3` share one, as do `UART0`/`UART1` and
   `TIMER0`/`TIMER1`. Costing them gives a figure to compare the two candidate
   sizes against:

   **Table 14 -- Estimated `ISRAM` occupancy for QSOC's peripheral set**

   | Item | RV32IMC, `-Os` |
   |---|---:|
   | `SCRC`, `SYSCSR`, `WDT` -- register writes and little else | ~1 KiB |
   | `GPIO` -- one driver, four instances | 0.5 KiB |
   | `TIMER` -- `apb_timer_unit`, 64-bit mode | 1 KiB |
   | `UART` -- ring buffer and interrupt handler | 1.5 KiB |
   | `SPI` -- host and device | 2.5 KiB |
   | `I2C` -- state machine | 2 KiB |
   | `PWM` -- `apb_adv_timer` | 1.5 KiB |
   | `DMA` -- `idma` descriptor setup | 1.5 KiB |
   | `INTMAP` and the interrupt dispatch | 1 KiB |
   | **The eleven drivers together** | **~12.5 KiB** |
   | `crt0`, startup, trap frame | 0.7 KiB |
   | A hand-written `printf` -- integer, hex, string | 2.5 KiB |
   | A bring-up application exercising all sixteen slaves | 5--8 KiB |
   | **Total, hand-written `printf`** | **~22 KiB** |
   | newlib-nano `printf` **with float**, in place of the hand-written one | 12--18 KiB |
   | **Total, newlib `printf`** | **~34 KiB** |

   A 32 KiB `ISRAM` leaves **28 KiB** for the main image once the debug program
   has its 4 KiB. The modest case consumes **79%** of that before a line of real
   test code is written, and the other case does not fit at all -- and `.rodata`,
   1--3 KiB of format strings and lookup tables, is still to be placed. 60 KiB
   accommodates both with room to grow.

   These are estimates and are labelled as such. The way to settle it properly is
   to measure: `riscv32-unknown-elf-size -A` on a representative image gives
   `text` and `rodata` for `ISRAM`, and `data + bss` -- plus the stack and heap --
   for `DSRAM`.
3. **Block RAM is not the constraint on the boards this will run on.** At 32 bits
   wide, 2 KiB of ROM is 2 M9K blocks, 32 KiB is 32 and 64 KiB is 64. A MAX 10
   10M50 has **182**:

   | | ROM | `ISRAM` | `DSRAM` | M9K used | of 182 |
   |---|---:|---:|---:|---:|---:|
   | 32 KiB `ISRAM` | 2 | 32 | 32 | 66 | 36% |
   | **64 KiB `ISRAM`** | 2 | 64 | 32 | **98** | **54%** |

   On an Artix-7 35T the same two come to 30% and 44% of 1,800 Kbit. Both fit
   both boards, and on a device of this class a SoC with a three-master crossbar
   and sixteen APB peripherals exhausts **logic elements** long before it
   exhausts block RAM. Block RAM is not the resource that decides this.
4. **The cost of being wrong is asymmetric, and that is what settles it.** Choose
   64 KiB and be wrong, and 32 M9K blocks sit unused -- 17% of the device, with
   43% still free. Nobody is blocked and nothing is rebuilt. Choose 32 KiB and be
   wrong, and it surfaces during integration, at the end of the project, once the
   firmware exists: `PARA_SRAM_DEPTH`, the interconnect's address rule for that
   slave, synthesis and the regression all move together. The edit itself is
   cheap either way; **when it is discovered is what costs.**

**ROM is 2 KiB, and the budget inside it is tight enough to state explicitly.** The
Day005 review of 2026-09-18 fixed ROM at **2 KiB** and the program inside it at **not
more than 1 KiB**; the ROM owner's own specification matches, decoding 11 address bits
for 512 words. This supersedes the 8 KiB that earlier revisions of this document
carried from `QSOC_HAS`, and it supersedes the `QSOC_HAS` bootloader budget of 1.1 KiB
with a bitwise CRC32 or 2.1 KiB with a table-driven one -- **the 2.1 KiB variant no
longer fits at all.**

What is left after the fixed cost:

| Item | Size | Note |
|---|---:|---|
| Trap vector table | **128 B** | `0x000` -- `0x07F`, forced by Ibex, Table 15 |
| Reset entry onward | **1920 B** | `0x080` -- `0x7FF`, all the code there is |
| Day005 budget for the program | **<= 1024 B** | leaves 896 B spare |

**Two consequences for this document.** The CRC32 must be the **bitwise** variant: a
256-entry table is 1 KiB of `rodata` on its own and would consume the whole budget
before any code. And the **payload copy loop writes into `ISRAM`** one word at a time,
which is still the only master that writes `ISRAM` before the application exists -- the
size change does not affect that path.

**This is the ROM owner's block, not this author's.** The figures are recorded here
because the memory map, the vector table and the copy target are shared, and because a
reader of this document should not be left with a stale 8 KiB.

**This corrects an earlier revision of this document, which had the application
arriving over JTAG and the ROM doing "very little: come out of reset, and wait".**
That was wrong: the instructor's direction and `QSOC_HAS` both put the boot flow in
ROM, over `UART0`, with the debug interface as the **second** path. The conclusion
this section reaches is unchanged -- `ISRAM` still has to hold the whole program, so
it still wants 60 KiB free -- but the reason is that the bootloader *puts* the
program there, not that a debugger does.

**The reset vector does not sit where the map suggests, and this is easy to get
wrong.** Ibex is given `boot_addr_i = 0x0000_0000`, but it does not fetch its
first instruction from there:

```systemverilog
// ibex_if_stage.sv
PC_BOOT: fetch_addr_n = { boot_addr_i[31:8], 8'h80 };
`ASSERT(IbexBootAddrUnaligned, boot_addr_i[7:0] == 8'h00)

// ibex_cs_registers.sv -- mtvec.BASE must be 256-byte aligned
mtvec_d = csr_mtvec_init_i ? {boot_addr_i[31:8], 6'b0, ...}
```

So `boot_addr_i` must be **256-byte aligned**, it becomes the reset value of
**`mtvec`**, and execution begins at **`boot_addr_i + 0x80`**. The first 128 bytes
of the ROM are therefore the trap vector table, not code:

**Table 15 -- ROM layout forced by the Ibex reset vector**

| ROM offset | Contents |
|---|---|
| `0x000` -- `0x07F` | `mtvec` base -- the trap vector table. In vectored mode this is 4 bytes per cause, and 32 causes is exactly `0x80` |
| `0x080` | **The reset entry point.** The first instruction the CPU ever executes |
| `0x084` onward | The rest of the boot code -- the reset entry holds one 32-bit instruction, normally a jump to it |

Placing boot code at offset zero is the failure this note exists to prevent: the
core would fetch from `0x080`, find whatever is there, and take an illegal
instruction trap before anything has been initialised -- with no error from the
bus to explain it.

## 5.2 Clock and reset domain

This section exists because `QSOC_HAS` carries an unresolved row that names this
document, and because the answer is available from the bus protocol rather than from
simulation.

**Both RAMs are one domain.** `QSOC_HAS` Table 4-2 assigns `ISRAM` and `DSRAM` to
domain **`D13`**, sharing **soft-reset bit 12** and one clock gate between them.
Neither RAM has a reset or a gate of its own, and the ROM is a separate domain,
`D12`, with bit 11. There is one clock frequency for the whole chip, so nothing here
crosses domains.

**Sharing one soft-reset bit has a consequence worth stating.** A write that resets
domain `D13` resets **both** RAMs, which means it resets the memory holding the code
that issued the write. Firmware executing from `ISRAM` cannot soft-reset the RAM
domain and survive; the write is only safe from ROM. That is not a defect -- there is
no use for resetting the RAM a program is running from -- but it is a loaded gun in
the register map and the `SYSCSR` owner should know it points here. `QSOC_HAS` EN v1.1 puts the same
trade-off to this author explicitly and keeps the domain shared; **this document
agrees**, and records the escape hatch that makes the decision reversible:
`SOFT_RST_CTRL` bits `[15:14]` are reserved, so splitting `ISRAM` and `DSRAM` into
two domains later costs a bit that already exists rather than a change to the
register layout.

**The boot-memory ordering question, and the answer.** `QSOC_HAS` records two
readings of what happens if the memory domain is still in reset when the core fetches
its first instruction, and leaves the row open pending simulation:

| Reading | Consequence |
|---|---|
| The controller does not accept the request | The bus handshake stalls, the core waits, and the situation corrects itself when the memory leaves reset |
| The fetch returns undefined data | The core traps before anything is initialised |

**The second reading cannot happen, and the reason is in the AXI specification rather
than in this controller.** AXI requires every `VALID` signal to be **deasserted while
reset is asserted**. A slave held in reset therefore cannot assert `rvalid`, and
without `rvalid` there is no read data for the core to receive -- undefined or
otherwise. The core sees `arready` low, holds `arvalid`, and waits. **So the ordering
is not a correctness requirement**, and the clock-and-reset specification is right
that no sequencing is needed for it.

**What it is instead is a liveness requirement, and that is worth more attention than
the ordering was.** Because AXI has no timeout, a core waiting on a memory that never
leaves reset waits **forever**, with no exception, no error and nothing in any status
register to say why. The only thing that can observe it is `SYSDBG`, which lives in its
own clock and reset domain, `D15`, released **before** the CPU
(`QNSC_SYSDBG_MAS` section 4.2), so it is still alive when the memory domain is not. It
can halt the core and read `arvalid` state over JTAG while the rest of the chip is
stuck.

**But observing is now all it can do.** The Day005 review of 2026-09-18 fixed the
chip's reset sources at three -- power-on, watchdog and software -- and **removed debug
reset**, so `SYSDBG` can see a stuck reset and report it but cannot clear it. Recovery
from this state is a power cycle. That makes the liveness requirement stronger than it
was when this paragraph was first written: **nothing in the chip rescues a memory domain
that never leaves reset**, so the clock and reset owner must guarantee it does.

## 5.3 Interfaces to agree with the team

**Table 16 -- Interfaces to agree with the team**

| Item | Owner of the other side | Why it matters |
|---|---|---|
| `S_BUS` AXI geometry: data width, address width, ID width | bus owner | Feeds `PARA_DATA_WD`, `PARA_ADDR_WD` and `PARA_ID_WD` |
| The memory map of section 5.1, and the `ISRAM` / `DSRAM` sizes | memory map owner, project level | Feeds `PARA_SRAM_DEPTH` on each macro and the interconnect's address rule for each slave |
| **A fourth slave port on `S_BUS`** | bus owner | Section 5.1 -- the RAM is now two instances: `ISRAM` on `AXI_M1`, `DSRAM` on `AXI_M2`, `AXI2APB` moving to `AXI_M3` |
| The `CPU2AXI` wrapper must carry `data_be_o` through to `wstrb` | CPU / bus owner | Table 5 -- an instruction fetch is always a full word, so the byte enables exist only on the data side and are easy to drop when the two are merged |
| Ibex `boot_addr_i` = `0x0000_0000` | CPU owner | The reset vector must land in the ROM |
| `0xF000_0000` left **unmapped** in the interconnect | bus owner | Table 10 -- the `SYSDBG` registers exist in the JTAG command space only and must not be shadowed by a bus slave |
| **Masters constrained to `INCR` and `FIXED`** | bus owner, CPU owner, DMA owner | Section 4.6 -- the `WRAP` path does not wrap |
| **Transfer size fixed at 32 bits** | bus owner | `AxSIZE` is not a port; a narrower request is ignored, not refused |
| `DECERR` for unmapped addresses returned by the bus decoder | bus owner | Section 4.7 -- the RAM answers `OKAY` to everything |
| SRAM macro with **byte write enables** | technology / FPGA owner | Section 4.4 -- required by the `WSTRB` path |
| **Unused macro pins tied to their databook defaults** -- margin, retention, test | technology / physical design owner | Section 4.8. Accepted from `QSOC_HAS`. The controller drives none of them and no simulation can fail because of them, so this is silicon-only risk |
| Whether the same controller instance is reused for the ROM | project level | It is suitable unmodified; only the macro differs |

## 5.4 Open questions

1. **Closed: both confirmations have arrived.** The ROM owner's own specification
   confirms the bootloader is theirs and fixes ROM at **2 KiB** with the program inside
   it at **not more than 1 KiB**, superseding the 1.1--2.1 KiB budget this item used to
   quote. The boot flow specification confirms `boot_addr_i = 0x0000_0000` **and** that
   Ibex fetches from `0x0000_0080`, citing `ibex_if_stage.sv:243`. Section 5.1 carries
   both numbers.

   **64 KiB of `ISRAM` remains the number to build against**, for the reasons in section
   5.1. Reducing it later is a change to `PARA_SRAM_DEPTH` and one address rule in the
   interconnect, with no RTL edit -- and because the debug program sits at the bottom of
   `ISRAM` rather than the top, no CPU parameter moves with it.

2. **Claimed: the `WSTRB` addition is this author's.** It lives in the wrapper around the controller, not inside the IP, and the RAM wrapper is this block's deliverable -- so no handover is needed and the work can start. Section 4.4. It is the one
   piece of RAM RTL this project writes, and it should be agreed before it is
   written rather than discovered in integration.
3. **Closed: out of scope for v1, and the reason is a read-path change rather than a
   missing module.** `prim_ram_1p_scr` presents a `req`/`rvalid` interface and adds read
   latency, whereas this controller assumes a **fixed one-cycle read**
   (`reg_rd_pending`). Adding scrambling and integrity would mean rebuilding the read
   path, not dropping a module in. Recorded as possible work for a later version, with
   the cost named so nobody mistakes it for an afternoon's integration.

**Two action items rather than open questions.** Both are things to do, not information
to wait for, and both go to the same person: `nguyenquanicd/AXI4-SRAM-CONTROLLER` is a
repository of the **project's own mentor**, the same account supplying
`APB-CSR-Generator`, `APB-BUS-Generator`, `FirstX2P` and `MRV-CPU` to QSOC.

| Action | Why it matters |
|---|---|
| **Ask the mentor what licence the IP carries.** The repository has **no `LICENSE` file**, so the terms are undefined rather than permissive | Every block that instantiates it inherits the answer -- ROM as well as RAM |
| **Report the `WRAP` finding**, with the reference in Appendix C | `WRAP` is declared and not implemented, section 4.6. The fix reaches its author directly and benefits ROM, which uses the same IP |

# 6. Observations

1. **Choosing an IP by bus protocol first was right, and reading its port list
   second was what made the choice safe.** `AXI4-SRAM-CONTROLLER` speaks AXI4
   natively, which is why it was selected; but the 33-port list is what revealed
   that `WSTRB` and `AxSIZE` are absent, and those two absences shape the rest of
   this specification. A feature table would not have shown it -- the README's own
   compliance table marks byte strobes as unsupported in one row and is easy to
   read past.
2. **A self-checking regression is only as correct as its reference model.**
   Section 4.6 is the clearest lesson in this document: 46 tests pass, four of
   them exercise `WRAP`, and the address calculation is wrong in the design and
   wrong in the same way in the checker. Reading the model, not just the pass
   rate, is what found it.
3. **The one gap is also the one contribution.** Everything this block does, it
   does already; the byte-enable path is the whole of what QSOC adds, and it is
   small. That is what a good integration looks like, and it is worth stating
   plainly rather than inflating.
4. This block and `SYSDBG` are specified from opposite directions, deliberately.
   The RAM is an **integration**: a proven controller, where the work is choosing
   it correctly, parameterising it, and adding the one path it does not have.
   Both, in the end, came down to the same activity -- reading somebody else's RTL
   closely enough to know exactly where it stops.

# Appendix A. Acronyms

**Table 17 -- Acronyms**

| Acronym | Description |
|---------|-------------|
| APB | Advanced Peripheral Bus |
| AXI | Advanced eXtensible Interface |
| FIFO | First In First Out buffer |
| FSM | Finite State Machine |
| IP | Intellectual Property block |
| QSOC | The MCU built in this training project |
| RTL | Register Transfer Level |
| SECDED | Single Error Correct, Double Error Detect |
| SRAM | Static Random Access Memory |
| VIP | Verification Intellectual Property, a pre-built verification component |
| WSTRB | AXI write strobe, one byte-enable bit per data byte |

# Appendix B. First Review

| Item | Reviewer | Response |
|------|----------|----------|
|      |          |          |
|      |          |          |

# Appendix C. References

1. VLSI Technology (`nguyenquanicd`), *AXI4 SRAM Controller*,
   <https://github.com/nguyenquanicd/AXI4-SRAM-CONTROLLER>
2. ARM, *AMBA AXI and ACE Protocol Specification*, IHI 0022
3. lowRISC, *OpenTitan*, primitives `prim_ram_1p_scr`, `prim_secded_inv_39_32`,
   <https://github.com/lowRISC/opentitan>
4. QSOC block diagram and IP assignment sheet, `VLSIT_DeepTraining_20260908`
5. **`QSOC_HAS`** -- the system architecture specification. Authority for the boot
   flow of section 5.1, the memory map, and the mandatory protocol conversions
6. `QNSC_SYSDBG_MAS` -- the companion specification for the author's second block

# V2.2 cuts (2026-09-24)

Text removed from `QNSC_RAM_MAS.md` V2.1 when V2.2 was made specification only.
Kept here short, as the record of why.

- **History.** V2.0 replaced nine earlier versions and a 300-line memory-map
  proposal; the map is now generated from `util/qsoc_contract.yml` (910 lines
  down to about 420 at V2.0). The V2.1 row also noted that the `SYSDBG` register
  row left the map; that is a `SYSDBG` change, not a RAM one.
- **Full-chip map.** The MAS now shows only the `AXI_M1` and `AXI_M2` rows
  (`gen:memory_map ports=AXI_M1,AXI_M2`); the whole map is in the contract.
- **Contrast with `SYSDBG`.** `SYSDBG` is designed in house; here the controller is
  existing IP, and the wrapper is the only RTL the project adds.
- **FIFO depth.** One `PARA_FIFO_DEPTH` sets all FIFOs: deeper absorbs longer
  bursts without back-pressure and costs registers; the write and read paths
  cannot be sized apart without editing the IP top level.
- **One read in flight** is the first thing to revisit if the RAM becomes a
  bottleneck.
- **Why the byte-enable path matters.** RV32 `sb` and `sh`, emitted for any
  `uint8_t`, packed field or string, would otherwise write the whole word and
  silently destroy the three neighbouring bytes, since `RRESP` is always OKAY.
  Where the enables travel: Ibex `data_be_o` -> `axi_from_mem` `mem_be_i` ->
  AXI `wstrb` -> `S_BUS` -> dropped by the controller -> restored by the wrapper
  -> macro byte enables. The IP's README states the missing `WSTRB` as a boundary,
  not a defect. V2.2 fixes the mechanism: a strobe FIFO in lockstep with `WFIFO`,
  no vendor change.
- **Why the WRAP defect passed the IP's tests.** The reference model in
  `sim/vcs/env/axi_svt_basic_env.sv` computes the same value,
  `next_addr = (curr_addr + 4) & 32'hFFFF_FFFC`, so the four `wrap_*` tests agree
  with the design, not with AXI. To report to the IP authors.
- **WRAP consequence.** `WRAP` exists for cache-line fills. `axi_from_mem` and
  `SYSDBG` issue single beats; only the DMA could burst. If it ever issues WRAP,
  `axi_burst_unwrap.sv` from `pulp-platform/axi`, already used for `S_BUS`, splits
  it into INCR bursts in front of this block.
- **SECDED.** If integrity is added later, `RRESP` becomes a real signal; `RFIFO`
  already carries its two bits.
- **Aliasing and growth.** A decode window larger than the macro would alias
  silently. HAS Table 5-2 sets the windows equal to the macro sizes, so the
  paragraph and its constraint row were removed; the reserved space above each RAM
  is for growth.
- **Macro pins.** The behavioural model has only functional pins; the SMIC macro
  adds margin, retention and test pins that the controller does not drive. A
  mis-tied pin is harmless in simulation and wrong only in silicon (a floating or
  asserted test pin reads back stale data), so the tie-offs are written down.
- **Accepted-limits list** (one read in flight, 32-bit transfer size, WRAP as INCR,
  no error reporting, one FIFO depth) repeated sections 7 and 10 and was dropped.
- **Verification.** Reusing the IP's 46-test regression was part of why this IP
  was chosen. The acceptance test is about the block QSOC ships, not the IP: a C
  program writing a `uint8_t` array leaves its neighbours intact.
- **Address alignment.** V2.1 required aligned addresses. Because the macro takes
  address bits `[..:2]` only, an unaligned single beat addresses its containing
  word; only narrow bursts remain wrong.
