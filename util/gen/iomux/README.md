# `util/gen/iomux` — IO MUX, generated

`iomux_pads.yml` is the source: the ports of `m_qnsc_iomux` on the IP side, the
function catalog (polarity and idle value of every function, with the vendored
RTL line it comes from) and the pad table (Pad List v3). `gen.sh` is the recipe
(`make gen IP=iomux`, checked by `make gen-check`):

| File | Written by |
|---|---|
| `m_qnsc_iomux_mux.sv` | `util/gen_iomux.py`: per muxed pad, b0 or b1 on its select bit; per fixed pad, its one function |
| `iomux_expect.svh` | `util/gen_iomux.py`: the checks `dv/iomux` runs |

The select register (`IOMUX_SEL`) is a register of SYSCSR, not generated here.

Before writing, `util/gen_iomux.py` checks the table: every function is in the
catalog and names existing ports the right way round; every IP input is reached
from exactly one pad (no priority needed, no port for nothing); every IP output
reaches a pad; the select bits are 0..N-1, one per muxed pad; the JTAG pads are
b0 of select bits 0-4; no pad uses a dedicated pin.

To change the pin map: edit `iomux_pads.yml`, `make gen IP=iomux`, `make sim
BLOCK=iomux`, commit the table and the regenerated files together.
