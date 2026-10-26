#!/usr/bin/env bash
# Clone a branch into scratch and run DC or PT in it (the run_vc_branch shape).
#   bash flow/signoff_run_branch.sh <block> <branch> <dc|pt>
set -euo pipefail
block=${1:?block}; branch=${2:?branch}; mode=${3:?dc|pt}
here=$(git rev-parse --show-toplevel)
url=$(git -C "$here" remote get-url origin)
case "$url" in /*) url="file://$url";; esac
dir="${QSOC_SCRATCH:-${TMPDIR:-/tmp}}/qsoc_${mode}_${USER:-me}/$block"
rm -rf "$dir"
git clone -q --depth 1 --branch "$branch" "$url" "$dir"
rc=0
case "$mode" in
  dc) (cd "$dir" && bash "$here/flow/dc/run_dc.sh" "$block" "$here/flow/dc") || rc=$? ;;
  pt) (cd "$dir" && bash "$here/flow/pt/run_pt.sh" "$block" "$here/flow/pt") || rc=$? ;;
esac
mkdir -p "$here/build/$mode/$block"
cp "$dir/build/$mode/$block/summary.txt" "$here/build/$mode/$block/" 2>/dev/null || true
cp -r "$dir/build/$mode/$block/reports" "$here/build/$mode/$block/" 2>/dev/null || true
cp -r "$dir/build/$mode/$block/results" "$here/build/$mode/$block/" 2>/dev/null || true
[ "$rc" -eq 0 ] && echo "PR comment, from your machine: make ${mode}-post BLOCK=$block PR=<n>"
exit $rc
