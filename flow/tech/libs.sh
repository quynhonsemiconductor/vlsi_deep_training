#!/usr/bin/env bash
# The cells every block may instantiate without listing them, as library files.
#
#   bash flow/tech/libs.sh            -> -v design/common/rtl/qnsc_sync.sv
#                                        -v design/common/tech/generic/qnsc_clk_gate.sv ...
#   TECH=<tech> bash flow/tech/libs.sh
#
# Two lists, one "-v <path>" per file, paths from the repository root:
#   design/common/common.f      shared RTL (qnsc_sync, ...), paths relative to design/common
#   design/common/tech/$TECH.f  technology cells (TECH=generic unless set), paths relative
#                               to design/common/tech
# Verilator, VCS and slang (yosys-slang) all take -v as a library file: a module in it is
# compiled only when the design instantiates it, so a cell no block uses is not an extra
# top, and a cell two blocks use is compiled once when their filelists are combined.
# Every flow appends this after the block's own filelist (Naming Rule 2.8).
set -euo pipefail
tech=${TECH:-generic}

emit() {   # emit <list> <directory the list's paths are relative to>
  local f=$1 dir=$2 p
  [ -f "$f" ] || { echo "no library list $f" >&2; exit 1; }
  for p in $(grep -vE '^[[:space:]]*(#|$)' "$f"); do
    [ -f "$dir/$p" ] || { echo "$f lists $p, which does not exist" >&2; exit 1; }
    printf -- '-v %s\n' "$dir/$p"
  done
}

emit design/common/common.f design/common
[ -f "design/common/tech/$tech.f" ] || { echo "no technology library design/common/tech/$tech.f (TECH=$tech)" >&2; exit 1; }
emit "design/common/tech/$tech.f" design/common/tech
