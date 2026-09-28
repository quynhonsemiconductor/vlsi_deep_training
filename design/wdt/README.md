# `wdt` — watchdog timer

**Owner:** @hieu-vubuiminh   **Spec:** [`QNSC_WDT_MAS.md`](../../doc/specs/QNSC_WDT_MAS.md)   **DV:** [`../../dv/wdt`](../../dv/wdt)

## What this block is

The watchdog on `APB_M2`: bark to the NMI, bite to a chip reset through `SCRC`,
plus a wake-up timer on line 8. Upstream `aon_timer` wrapped unmodified by
`m_qnsc_wrap_wdt`, with the shared APB-to-TL-UL bridge. Never clock-gated.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `lowRISC/opentitan` | `aon_timer`, `tlul_adapter_host` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`wdt.f`](./wdt.f), never copied into `rtl/`. Reading this one directory answers
what is ours and what is borrowed.

## Instances

One.
