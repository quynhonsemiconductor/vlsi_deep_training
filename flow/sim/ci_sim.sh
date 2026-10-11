#!/usr/bin/env bash
# Simulation of the blocks a change touches (CI job "Simulation").
#
#   bash flow/sim/ci_sim.sh [BASE]          BASE: the commit to compare with
#
# A block is touched when design/<block>/ or dv/<block>/ changed. A change to what
# every block compiles -- design/common/, flow/sim/, flow/tech/, vendor/ -- touches
# every block. A touched block with no dv/<block>/tb_<block>.sv yet is listed as
# skipped and does not fail: a testbench is the SIM stage, not part of an RTL pull
# request (CONTRIBUTING.md, "Sign-off stages"). A block that has one runs every
# test, so a change cannot break tests that already pass.
#
# Writes build/sim/report.md and exits 1 if a testbench fails. A failing block is
# run again with WAVES=1, so its waveform can be kept as a CI artifact.
set -uo pipefail
base=${1:-origin/main}
mkdir -p build/sim
report=build/sim/report.md
changed=$(git diff --name-only "$base"...HEAD)

if echo "$changed" | grep -qE '^(design/common/|flow/sim/|flow/tech/|vendor/)'; then
  blocks=$(ls -d design/*/ | xargs -n1 basename)
  why="a change to code every block compiles"
else
  blocks=$(echo "$changed" | awk -F/ '($1=="design"||$1=="dv") && NF>2 {print $2}' | sort -u)
  why="blocks changed in this pull request"
fi

rows=() ; skipped=() ; rc=0 ; ran=0
for b in $blocks; do
  [ "$b" = common ] || [ "$b" = top ] && continue
  [ -d "design/$b" ] || continue
  if [ ! -f "dv/$b/tb_$b.sv" ]; then
    skipped+=("\`$b\`")
    continue
  fi
  ran=$((ran + 1))
  log="build/sim/$b/sim.log"
  if bash flow/sim/run_sim.sh "$b" > "build/sim/$b.out" 2>&1; then
    tests=$(grep -cE '^[A-Z]+_[0-9]{3} ok' "$log" || true)
    rows+=("| \`$b\` | **PASS** | $tests test(s) |")
  else
    rc=1
    why_fail=$(grep -m1 -E '%Fatal|%Error|Error' "build/sim/$b.out" | sed 's/|/\\|/g' | cut -c1-160)
    rows+=("| \`$b\` | **FAIL** | ${why_fail:-see the job log} |")
    WAVES=1 bash flow/sim/run_sim.sh "$b" > /dev/null 2>&1 || true
  fi
done

{
  if [ ${#rows[@]} -eq 0 ] && [ ${#skipped[@]} -eq 0 ]; then
    echo "no block with RTL or a testbench changed"
  else
    echo "Blocks simulated: $why. Verilator 2-state; X is checked with VCS on the server."
    echo
    echo "| Block | Result | Detail |"
    echo "|---|---|---|"
    [ ${#rows[@]} -gt 0 ] && printf '%s\n' "${rows[@]}"
    if [ ${#skipped[@]} -gt 0 ]; then
      list=$(printf '%s, ' "${skipped[@]}"); list=${list%, }
      echo "| ${#skipped[@]} block(s) | skipped | no \`dv/<block>/tb_<block>.sv\` yet: $list |"
    fi
    if [ $ran -gt 0 ]; then
      echo
      echo "<details><summary>Tests</summary>"
      echo
      for b in $blocks; do
        [ -f "build/sim/$b/sim.log" ] || continue
        echo "\`$b\`"
        echo
        grep -E '^[A-Z]+_[0-9]{3} ok' "build/sim/$b/sim.log" | sed 's/^/- /'
        echo
      done
      echo "</details>"
    fi
  fi
} > "$report"
cat "$report"
exit $rc
