# `util/` — the contract, its generator, and the vendoring tool

| File | What it is | Run |
|---|---|---|
| `qsoc_contract.yml` | **The single source of truth** for every number shared between blocks: memory map, bus ports, interrupt lines, clock and reset domains, and the `tbd:` list of numbers not yet agreed | edit, then `make pkg` |
| `gen_qnsc_pkg.py` | Generates `design/top/rtl/qnsc_pkg.sv` from the contract | `make pkg`, checked by `make pkg-check` |
| `vendor_ip.py` | Copies an upstream IP into `vendor/` at the commit pinned in `vendor/manifest.yml`, applies `vendor/patches/`, and records the SHA in `vendor/vendor.lock.yml` | `python3 util/vendor_ip.py --list` |

The specification tables that restate the contract are generated from it too,
by [`doc/build/tools/gen_doc_tables.py`](../doc/build/tools/gen_doc_tables.py) (`make tables`).

How to change a shared number is in
[`CONTRIBUTING.md`, "Changing a shared number"](../CONTRIBUTING.md#changing-a-shared-number).
