# `pbus` — P_BUS, the APB4 peripheral bus

**Owner:** @Nam-HaoNguyen   **Spec:** `QNSC_PBUS_MAS` on the team SharePoint   **DV:** [`../../dv/pbus`](../../dv/pbus)

## What this block is

P_BUS takes the one APB port of the AXI2APB bridge (18-bit address, the offset in
the 256 KiB window 0x8000_0000-0x8003_FFFF) and routes each access to one of
fourteen APB slaves, by the slot `paddr[17:14]`. Each slave receives the offset
in its 16 KiB slot, `paddr[13:0]`. Slots 14 and 15 have no slave: an access there
is answered at once with `PREADY = 1`, `PSLVERR = 1`, `PRDATA = 0`.

It is combinational: no clock, no reset, no flip-flop, no timeout. A slave that
never raises PREADY is recovered by the WDT.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `nguyenquanicd/APB-BUS-Generator` (mentor's generator), output committed in [`util/gen/p_bus`](../../util/gen/p_bus) | `m_qnsc_p_bus` (generated `m_vlsi_apb_router`, renamed), `m_qnsc_p_bus_dec`, `m_qnsc_p_bus_arb_<slave>` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

The generator input is [`util/gen/p_bus/p_bus.xlsx`](../../util/gen/p_bus/p_bus.xlsx),
in the format of the mentor's `APB_BUS_Example.xlsx`. Every number in it comes from
the contract:

| Workbook | Value | Contract |
|---|---|---|
| CFG, master `AXI2APB`, ADDRESS WIDTH | 18 | `meta.pbus_paddr_width` |
| CFG, each slave, ADDRESS WIDTH | 14 | `meta.apb_paddr_width` |
| MM-CFG, slave base | contract base - 0x8000_0000 (`0x0`, `0x4000`, ... `0x34000`) | `memory_map.<slave>.base`, port `APB_M0..13` |
| CFG, PSLVERR on unmapped access | 1 | QNSC_PBUS_MAS |

Facts of the generated RTL this block relies on (read in the generated files):

- the decoder compares the whole 18-bit address against each range, end
  inclusive, and its `default` branch is the unmapped answer above
  (`m_qnsc_p_bus_dec.sv`);
- a slave receives `14'(i_paddr - base)`. The slots are aligned to their size, so
  this is the same 14 bits as `paddr[13:0]`;
- with one master every arbiter is plain assignments: `i_clk`/`i_rstn` reach the
  arbiters but no flip-flop uses them (`m_qnsc_p_bus_arb_*.sv`);
- the generator adds three sideband signals per port, `pprot`, `protect_en`,
  `slverr_en`, passed through unchanged.

`util/gen/p_bus/gen.sh` renames the generated modules (`m_vlsi_*` breaks Naming
Rule 2.1 and collides with the SCRC internal bus, made by the same tool) and fixes
the `Author:` header line, so a regeneration is byte-identical.

## The wrapper is the boundary

`rtl/` holds **only code written here**: the emacs wrapper
`m_qnsc_wrap_pbus` (source `rtl/emacs/m_qnsc_wrap_pbus.src.sv`, `make wrap
BLOCK=pbus`). It adds no logic. It names the ports by Naming Rule 3.3
(`i_bus_apb_s_0_*` from the bridge, `o_bus_apb_m_<n>_*` to slave `APB_Mn`), ties
the router's unused `i_clk`/`i_rstn`, and ties the sideband inputs to 0 with their
outputs left open: the bridge drives no PPROT, and `design/top` ties each slave's
PPROT.

## Instances

One, in `design/top`, between the AXI2APB bridge and the APB guards of SCRC.

## Sign-off stages

| Stage | Status |
|---|---|
| CDC, RDC | waived: no clock, no reset, no flip-flop |
| SDC | none: the paths are constrained by the bridge, guard and slave flip-flops at both ends |
