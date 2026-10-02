#!/usr/bin/env bash
# The technology cells of one technology, as library files for a tool.
#
#   bash flow/tech/libs.sh            -> -v design/common/tech/generic/qnsc_clk_gate.sv ...
#   TECH=<tech> bash flow/tech/libs.sh
#
# Reads design/common/tech/$TECH.f (TECH=generic unless set) and prints one
# "-v <path>" per cell, paths from the repository root. Verilator, VCS and slang
# (yosys-slang) all take -v as a library file: a module in it is compiled only
# when the design instantiates it, so a cell no block uses is not an extra top.
# Every flow appends this after the block's own filelist (Naming Rule 2.8).
set -euo pipefail
tech=${TECH:-generic}
dir=design/common/tech
f="$dir/$tech.f"
[ -f "$f" ] || { echo "no technology library $f (TECH=$tech)" >&2; exit 1; }
for p in $(grep -vE '^[[:space:]]*(#|$)' "$f"); do
  [ -f "$dir/$p" ] || { echo "$f lists $p, which does not exist" >&2; exit 1; }
  printf -- '-v %s\n' "$dir/$p"
done
