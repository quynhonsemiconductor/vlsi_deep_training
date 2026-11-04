#!/bin/bash
# =============================================================================
# Compile the wdt block (m_qnsc_wrap_wdt) with Synopsys VCS: the syntax and
# elaboration check required before an RTL release.
#
#   ./run_vcs.sh                 from anywhere; outputs land in this directory
#
# The design comes from ../wdt.f, read with -F so its relative paths resolve
# from the filelist (the same list lint, SIM and SYN use). Same flags as
# flow/vcs/run_vcs (make vcs BLOCK=wdt).
# Training server: on a compute node, e.g. srun --nodelist=black -c 2 ./run_vcs.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v vcs >/dev/null 2>&1; then
  source /usr/share/Modules/init/bash
  module use /tools/eda/modulefiles
  module load synopsys/vcs/W-2024.09-SP1 synopsys/verdi/W-2024.09-SP1
fi

rc=0
vcs -full64 -sverilog +vcs+lic+wait \
    -timescale=1ns/1ps \
    -F ../wdt.f \
    -top m_qnsc_wrap_wdt \
    -debug_access -kdb -lca \
    +error+100 +lint=all \
    -Mdir=csrc -o simv \
    -l comp.log > comp.out 2>&1 || rc=$?

nerr=$(grep -cE '^Error-' comp.log || true)
nlint=$(grep -cE '^Lint-' comp.log || true)
echo "VCS compile m_qnsc_wrap_wdt: Error-: $nerr, Lint-: $nlint (full log: comp.log)"
if [ "$rc" -ne 0 ] || [ "$nerr" -gt 0 ]; then
  grep -A4 -E '^Error-' comp.log | sed -n 1,40p
  echo "Result: FAIL"; exit 1
fi
echo "Result: PASS"
