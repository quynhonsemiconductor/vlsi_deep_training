#!/usr/bin/env bash
# SIM stage ("VCS" on the tracker): simulate one block with Verilator.
#
#   bash flow/sim/run_sim.sh <block> [test]
#
# Builds dv/<block>/tb_<block>.sv against design/<block>/<block>.f -- the same
# filelist the LINT stage uses, so what is simulated is what is linted. An
# optional dv/<block>/tb.f lists extra testbench files (models, packages).
# The test name, if given, reaches the testbench as the plusarg +test=<name>.
#
# Pass criterion: the testbench prints a line containing "PASS" and returns 0;
# a failure calls $fatal. See dv/README.md.
set -euo pipefail

block=${1:?usage: run_sim.sh <block> [test]}
test=${2:-}
flist="design/${block}/${block}.f"
tb="dv/${block}/tb_${block}.sv"
extra="dv/${block}/tb.f"
out="build/sim/${block}${test:+_${test}}"

[ -f "$flist" ] || { echo "no $flist"; exit 1; }
[ -f "$tb" ]    || { echo "no $tb yet -- see dv/README.md"; exit 1; }
mkdir -p "$out"

verilator --binary --timing -Wno-fatal -j 0 \
  --top-module "tb_${block}" -Mdir "$out" \
  -F "$flist" $( [ -f "$extra" ] && echo "-F $extra" ) "$tb"

"$out/Vtb_${block}" ${test:+"+test=${test}"} | tee "$out/sim.log"
grep -q "PASS" "$out/sim.log"
