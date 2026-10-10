#!/usr/bin/env bash
# SIM stage ("VCS" on the tracker): simulate one block with Verilator.
#
#   bash flow/sim/run_sim.sh <block> [test]
#   WAVES=1 bash flow/sim/run_sim.sh <block> [test]      # also write a waveform
#
# Builds dv/<block>/tb_<block>.sv against design/<block>/<block>.f -- the same
# filelist the LINT stage uses, so what is simulated is what is linted -- plus the
# technology cells of $TECH (flow/tech/libs.sh, as every other flow). An optional
# dv/<block>/tb.f lists extra testbench files (models, packages).
# The test name, if given, reaches the testbench as the plusarg +test=<name>.
#
# WAVES=1 builds with --trace (VCD: no extra library, every viewer opens it) and passes +waves=<file>; the testbench dumps
# when that plusarg is present (dv/README.md, "Waveforms"). The file is
# build/sim/<block>[_<test>]/waves.vcd; open it with Surfer or GTKWave.
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
tech=$(bash flow/tech/libs.sh)
trace=(); waves=()
if [ "${WAVES:-0}" = 1 ]; then
  trace=(--trace --trace-structs)
  waves=("+waves=$out/waves.vcd")
fi
verilator --binary --timing -Wno-fatal -j 0 ${trace[@]+"${trace[@]}"} \
  --top-module "tb_${block}" -Mdir "$out" \
  -F "$flist" $( [ -f "$extra" ] && echo "-F $extra" ) $tech "$tb"
"$out/Vtb_${block}" ${test:+"+test=${test}"} ${waves[@]+"${waves[@]}"} | tee "$out/sim.log"
grep -q "PASS" "$out/sim.log"
[ "${WAVES:-0}" = 1 ] && echo "waveform: $out/waves.vcd"
exit 0
