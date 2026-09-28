#!/usr/bin/env bash
# GCA stage: check the block's SDC with OpenSTA (open-source stand-in for
# Synopsys Galaxy Constraint Analyzer).
#
#   LIBERTY=/path/to/cells.lib bash flow/sta/run_gca.sh <block> [top]
#
# The SMIC 28 nm library is not open, so the check maps the block onto an open
# library (for example SkyWater sky130_fd_sc_hd) purely to have cells OpenSTA can
# time. The point of the stage is the constraints, not the timing numbers.
set -euo pipefail

: "${LIBERTY:?set LIBERTY to an open Liberty file, e.g. sky130_fd_sc_hd__tt_025C_1v80.lib}"
block=${1:?usage: run_gca.sh <block> [top]}
flist="design/${block}/${block}.f"
sdc="design/${block}/constraints/${block}.sdc"
top=${2:-$(grep -oE 'rtl/[A-Za-z0-9_]+\.sv' "$flist" | tail -1 | xargs -n1 basename | sed 's/\.sv$//')}
out="build/sta/${block}"
[ -f "$sdc" ] || { echo "no $sdc yet -- see flow/sta/README.md"; exit 1; }
mkdir -p "$out"

yosys -m slang -q -l "$out/map.log" -p "
  read_slang -F ${flist} --top ${top}
  synth -top ${top}
  dfflibmap -liberty ${LIBERTY}
  abc -liberty ${LIBERTY}
  opt_clean
  write_verilog -noattr ${out}/${top}.v
"

LIBERTY="$LIBERTY" NETLIST="$out/${top}.v" TOP="$top" SDC="$sdc" \
  sta -exit flow/sta/check_sdc.tcl | tee "$out/gca.log"
