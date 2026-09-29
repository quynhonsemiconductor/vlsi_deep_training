#!/usr/bin/env bash
# Connectivity report for the blocks a change touches (CI job "Connectivity").
#
#   bash flow/conn/ci_report.sh [BASE]      BASE: the commit to compare with
#
# A block counts as touched when a file under design/<block>/ changed. Writes
# build/conn/report.md (one section per block) and exits 1 if any block fails
# (a floating instance input, an undriven top output).
set -uo pipefail
base=${1:-origin/main}
out=build/conn; mkdir -p "$out"; report="$out/report.md"; : > "$report"
blocks=$(git diff --name-only "$base"...HEAD -- design | awk -F/ 'NF>2 {print $2}' | sort -u)
rc=0; n=0
for b in $blocks; do
  [ "$b" = common ] && continue          # shared cells, each checked where it is used
  [ -f "design/$b/$b.f" ] || continue
  sec=$(python3 flow/conn/connectivity.py "$b" --out "$out/$b" 2>&1); r=$?
  case "$sec" in *"skipped"*) continue;; esac
  n=$((n+1)); [ $r -ne 0 ] && rc=1
  printf '%s\n\n' "$sec" >> "$report"
done
if [ "$n" -eq 0 ]; then echo "no block with RTL changed" > "$report"; fi
cat "$report"
exit $rc
