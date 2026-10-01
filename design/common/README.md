# `common` — shared RTL

Code instantiated by **more than one block**. The case this directory exists for is
the **APB-to-TL-UL adapter**: both `spi` and `wdt` need one, and writing it twice
means the two copies diverge the first time somebody fixes a bug in one. It is
`qnsc_apb_to_tlul`, the APB handshake around the upstream `tlul_adapter_host`,
specified in [`QNSC_WDT_MAS`](../../doc/specs/QNSC_WDT_MAS.md) 7.5.

**Owner:** maintainers — a change here affects every block that instantiates it,
so it is not a block owner's file.

Put something here only when a second block actually needs it. One user is not
shared code.

Technology cells (clock gate, clock mux, and later pads and macros) are in
[`tech/`](tech/README.md): one generic implementation, one per ASIC library, chosen
with `TECH`.
