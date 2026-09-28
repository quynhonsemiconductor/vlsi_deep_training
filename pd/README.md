# `pd/` — implementation (SYN and GCA stages, and later physical design)

QSOC is a training project, so the implementation flow uses open-source tools.

| Stage | Tool | Script | Output |
|---|---|---|---|
| SYN | Yosys + `yosys-slang` | `flow/syn/run_syn.sh <block>` | `build/syn/<block>/`: generic netlist, `syn.log` with the cell count |
| GCA | OpenSTA `check_setup` | `flow/sta/run_gca.sh <block>` | `build/sta/<block>/gca.log` |
| Place and route (later) | OpenROAD, on an open PDK | to be added here | — |

The SMIC 28 nm libraries are not open, so any step that needs cells uses an open PDK
(for example SkyWater sky130) as a stand-in. The numbers it reports are indicative;
the stages check that the design is synthesisable and correctly constrained.

Scripts shared by every block live in `flow/`. This directory holds chip-level
implementation work: the top-level floorplan and pad ring, once they exist.
