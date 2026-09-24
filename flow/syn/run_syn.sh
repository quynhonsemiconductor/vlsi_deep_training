#!/usr/bin/env bash
# SYN stage: synthesise one block with Yosys, generic cells.
#
#   bash flow/syn/run_syn.sh <block> [top]
#
# Needs Yosys with the yosys-slang front end (read_slang), because the vendored
# IP uses SystemVerilog packages, structs and interfaces that Yosys' own reader
# does not accept. The top defaults to the wrapper, the last rtl/*.sv line of
# design/<block>/<block>.f.
#
# Pass criterion: no latch, no multi-driven or undriven net (check -assert), and
# the cell count in build/syn/<block>/syn.log goes into the tracker comment.
set -euo pipefail

block=${1:?usage: run_syn.sh <block> [top]}
flist="design/${block}/${block}.f"
top=${2:-$(grep -oE 'rtl/[A-Za-z0-9_]+\.sv' "$flist" | tail -1 | xargs -n1 basename | sed 's/\.sv$//')}
out="build/syn/${block}"
mkdir -p "$out"

yosys -m slang -l "$out/syn.log" -p "
  read_slang -F ${flist} --top ${top}
  synth -top ${top}
  select -assert-none t:\$_DLATCH* t:\$dlatch
  check -assert
  stat
  write_verilog -noattr ${out}/${top}_generic.v
"
