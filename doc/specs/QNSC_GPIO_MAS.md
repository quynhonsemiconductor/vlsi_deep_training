---
title: "GPIO"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V1.3"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

# Revision history

: Revision history

| Version | Date | Author | Reviewer | Description of change |
|---------|------------|-------------|----------|--------------------------------------------|
| V1.3 | 2026-09-28 | Bui Hieu | -- | Added the GPIO wrapper contract and verification requirements |

# 1. Overview

GPIO gives software control of eight bidirectional GPIO functions and detects
input edges on those functions. QSOC uses one reusable `m_qnsc_wrap_gpio`
wrapper around the PULP `apb_gpio` IP and plans three top-level instances,
providing 24 GPIO functions.

The wrapper renames ports, fixes the IP configuration and ties off the unused
DFT input. It does not implement the IO MUX, pad cells, APB routing, access
protection or interrupt aggregation.

# 2. Features

- Eight GPIO functions per wrapper instance.
- Independent output value and active-high output enable for each GPIO.
- Two-stage input synchronisation in the peripheral clock domain.
- Per-pin falling-edge, rising-edge or both-edge interrupt selection.
- Sticky per-pin interrupt status with read-to-clear behaviour.
- Four pad-configuration bits per GPIO.
- Zero-wait-state 32-bit APB interface.
- One interrupt pulse output per wrapper instance.

# 3. Block diagram

The implemented signal flow is:

```text
P_BUS -> APB register and decode logic -> PADOUT and PADDIR -> IO MUX -> pad
pad -> IO MUX -> two-stage synchroniser -> PADIN and edge detector
edge detector -> interrupt qualification -> o_int_gpio and INTSTATUS
```

The wrapper and all sequential logic in `apb_gpio` use `i_clk_peri` and
asynchronous active-low `i_rst_n_peri`. The current repository does not yet
contain the three top-level GPIO instantiations.

# 4. IP used

: Upstream IP used

| From | Module | Commit | Licence |
|----------------------|----------------|------------------------------------------|------------------------------|
| `pulp-platform/apb_gpio` | `apb_gpio` | `f82caeb7f7d89427f05e9af5ed31e0675efe0d83` | SolderPad Hardware License 0.51 |

# 5. Interface

: GPIO wrapper interface

| Signal | Dir | Width | Description |
|------------------------------|--------|-----------:|-----------------------------------|
| `i_clk_peri` | in | 1 | Peripheral-domain clock connected to IP port `HCLK` |
| `i_rst_n_peri` | in | 1 | Asynchronous active-low reset connected to `HRESETn` |
| `i_bus_apb_paddr` | in | 12 | Local APB offset; the IP decodes only bits `[6:2]` |
| `i_bus_apb_psel` | in | 1 | APB slave select |
| `i_bus_apb_penable` | in | 1 | APB access-phase indicator |
| `i_bus_apb_pwrite` | in | 1 | APB write indicator |
| `i_bus_apb_pwdata` | in | 32 | APB write data |
| `o_bus_apb_prdata` | out | 32 | APB read data from the IP |
| `o_bus_apb_pready` | out | 1 | APB completion; the selected IP revision drives constant 1 |
| `o_bus_apb_pslverr` | out | 1 | APB error; the selected IP revision drives constant 0 |
| `i_pad_gpio` | in | 8 | Input values from the IO MUX and pad input receivers |
| `o_pad_gpio` | out | 8 | Output values toward the IO MUX and pads |
| `o_pad_gpio_oe` | out | 8 | Active-high output enable; bit `n` controls GPIO `n` |
| `o_pad_gpio_cfg` | out | 32 | Flattened pad configuration; bits `[4*n +: 4]` configure GPIO `n` |
| `o_int_gpio` | out | 1 | OR of qualified edge events in this instance |

The upstream `gpio_in_sync` output is intentionally left open. Software reads
the sampled input through `PADIN`; no QSOC block consumes a second copy.

# 6. Register map

Only GPIO fields 0 through 7 are implemented. Unimplemented upper read bits are
zero. Writes to upper bits have no effect.

: GPIO register map

| Offset | Register | Field | Bits | Access | Reset | Description |
|--------:|------------|--------|------:|--------|--------:|----------------------------------------------|
| `0x00` | `PADDIR` | DIR | 7:0 | RW | `0x00` | `1` enables output drive; `0` releases the GPIO output |
| `0x04` | `GPIOEN` | EN | 7:0 | RW | `0x00` | Enables input sampling clock and per-pin interrupt qualification |
| `0x08` | `PADIN` | IN | 7:0 | RO | `0x00` | Previous synchronised input sample used by edge detection |
| `0x0C` | `PADOUT` | OUT | 7:0 | RW | `0x00` | Output value |
| `0x10` | `PADOUTSET` | SET | 7:0 | WO | -- | Writing `1` sets the corresponding `PADOUT` bit |
| `0x14` | `PADOUTCLR` | CLR | 7:0 | WO | -- | Writing `1` clears the corresponding `PADOUT` bit |
| `0x18` | `INTEN` | EN | 7:0 | RW | `0x00` | Per-pin interrupt enable |
| `0x1C` | `INTTYPE` | TYPE | 15:0 | RW | `0x0000` | Two bits per pin: `00` falling, `01` rising, `10` both edges, `11` disabled |
| `0x24` | `INTSTATUS` | STATUS | 7:0 | RC | `0x00` | Sticky event status; reading clears all implemented status bits |
| `0x28` | `PADCFG` | CFG | 31:0 | RW | `0x0000_0000` | Four configuration bits per GPIO |

# 7. Functional behaviour

## 7.1 APB access

An access completes when `PSEL` and `PENABLE` are asserted. The selected IP
revision drives `PREADY=1` and `PSLVERR=0`, so the wrapper adds no wait state or
error response.

The IP decodes `PADDR[6:2]`. Address bits `[11:7]` and `[1:0]` do not participate
in register selection, so offsets that differ only in those bits alias. This
aliasing is accepted by the QSOC APB integration rule.

The IP has no `PSTRB` or `PPROT` port. The wrapper does not emulate either
signal. Firmware shall use aligned 32-bit writes; a sub-word write is unsupported
and may replace the complete addressed register value. Access protection, if
required, is implemented in the interconnect.

## 7.2 Output path

`PADOUT[n]` drives `o_pad_gpio[n]`. `PADDIR[n]` drives active-high
`o_pad_gpio_oe[n]`. `PADOUTSET` and `PADOUTCLR` modify `PADOUT` without a
software read-modify-write operation.

The IO MUX selects whether the GPIO function reaches a physical pad. When the
GPIO function is selected, the pad drives `o_pad_gpio[n]` only while
`o_pad_gpio_oe[n]` is 1.

## 7.3 Input path

`i_pad_gpio[n]` passes through two synchroniser flip-flops. A third register
keeps the previous synchronised sample for edge detection and supplies the
`PADIN` read value.

Input sampling clocks are enabled in groups of four GPIOs. `GPIOEN[3:0]`
collectively enables sampling for GPIO 0 through 3, and `GPIOEN[7:4]`
collectively enables sampling for GPIO 4 through 7. Interrupt qualification
still requires the corresponding per-pin `GPIOEN[n]` bit.

## 7.4 Interrupt path

For pin `n`, an interrupt event requires `GPIOEN[n]=1`, `INTEN[n]=1` and an edge
selected by `INTTYPE[n]`. Qualified events are OR-reduced to the one-cycle
`o_int_gpio` pulse. `INTSTATUS[n]` records the pin that produced the event.

Reading `INTSTATUS` clears all eight implemented status bits. If a qualified
event and an `INTSTATUS` read occur in the same cycle, event set has priority
over read-clear.

## 7.5 Reset

Asserting `i_rst_n_peri=0` clears direction, output value, input samples, GPIO
enable, interrupt enable, interrupt type, interrupt status and pad
configuration. The output value and output enable are therefore both low after
reset.

# 8. Instances

: Planned GPIO instances

| Instance | APB port | Base address | GPIO functions | Interrupt output |
|----------|----------|----------------:|---------------:|-----------------:|
| GPIO0 | `APB_M3` | `0x8000_C000` | 8 | 1 |
| GPIO1 | `APB_M4` | `0x8001_0000` | 8 | 1 |
| GPIO2 | `APB_M5` | `0x8001_4000` | 8 | 1 |

The three instances use the same wrapper and fixed IP configuration. The
top-level integration is planned but is not implemented in the current RTL.

# 9. What is not provided here and who provides it

: Functions this block does not provide

| Function | Where it lives |
|------------------------------------------------|------------------------------------------------|
| APB address routing and base-address subtraction | P_BUS in `design/bus` |
| GPIO function selection and signal sharing | `design/iomux` |
| Physical input, output and output-enable cells | IOPAD integration |
| Aggregation of three GPIO interrupt outputs | `design/intmap` |
| APB access protection | P_BUS or another integration-level policy block |

# 10. Tie-offs

: GPIO wrapper tie-offs

| Port | Tied to | Why |
|----------------------|-----------|---------------------------------------------------------|
| `dft_cg_enable_i` | `1'b0` | QSOC v1 has no system DFT control source |
| `gpio_in_sync` | open | Software reads the sampled value through `PADIN`; no second consumer exists |

# 11. Requirements on others and open items

: Requirements on other owners

| Item | Owner | What it blocks |
|--------------------------------------------------|--------------------------|------------------------------|
| Instantiate three wrappers on `APB_M3`, `APB_M4` and `APB_M5` | TOP owner | Chip-level GPIO access |
| Connect `i_pad_gpio`, `o_pad_gpio`, `o_pad_gpio_oe` and `o_pad_gpio_cfg` | IO MUX and IOPAD owners | Physical GPIO operation |
| Route the three `o_int_gpio` outputs to the agreed interrupt line | INTMAP and TOP owners | CPU GPIO interrupt delivery |
| Use aligned 32-bit GPIO writes | Firmware owner | Correct operation without `PSTRB` |
| Revisit `dft_cg_enable_i` when a DFT strategy is defined | DFT and TOP owners | Scan/test clock operation |

# 12. Verification

The self-checking GPIO regression shall verify:

1. reset values and disabled outputs;
2. APB full-word read and write of direction, output and pad configuration;
3. `PADOUTSET` and `PADOUTCLR` behaviour;
4. documented address aliasing;
5. synchronised input visibility in `PADIN`;
6. rising, falling and both-edge interrupt selection;
7. `INTSTATUS` read-to-clear behaviour and set priority;
8. eight GPIO functions, 32 pad-configuration bits, one interrupt output, and
   constant `PREADY=1` and `PSLVERR=0` responses.

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|----------|----------------------------------------------------------|
| APB | Advanced Peripheral Bus |
| DFT | Design for Test |
| GPIO | General-Purpose Input Output |
| IP | Intellectual Property block |
| IO MUX | Input Output Multiplexer |
| RC | Read to Clear |

# Appendix B. First review

: First review

| Item | Reviewer | Response |
|----------------------------------|----------------------|--------------------------------------------------|
| Add `PSTRB` and `PPROT` in the wrapper | Mentor feedback | Not added; document the upstream limitation and leave the ports unconnected at top level |
| Number of GPIO banks | Team decision | Three instances of eight GPIO functions, 24 functions total |
| Wrapper generation method | Mentor feedback | Emacs verilog-mode AUTO flow is used for source and generated RTL |
