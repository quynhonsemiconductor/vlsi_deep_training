# `top` — chip top level and the shared contract package

**Owner:** maintainers   **Spec:** the HAS (`doc/reference/QSOC_HAS_Report_EN_v4_final.docx`) and [`util/qsoc_contract.yml`](../../util/qsoc_contract.yml)   **DV:** [`../../dv/top`](../../dv/top)

## What this block is

The chip top level: it instantiates every block wrapper once per instance and
connects them by the naming rule — the buses, `INTMAP`, `SCRC` clocks and resets,
the IO MUX and the boot address. It writes no block logic of its own.

It also holds `rtl/qnsc_pkg.sv`, the package every wrapper imports. That file is
**generated** from `util/qsoc_contract.yml` (`make pkg`) and never edited by hand;
CI regenerates it and fails on a difference.

## Uses (IP)

None directly. Every IP enters through its block's wrapper.

## Instances

`design/top` is where instance counts live: two UARTs, three GPIOs, two timers,
two RAMs, one of everything else (table in [`design/README.md`](../README.md)).
What differs between two instances of one wrapper is a parameter or a port, never
a forked file.

## Ownership

A shared surface: a change here can move another block's address, interrupt line
or clock. It is reviewed by the maintainers, not by a block owner.
