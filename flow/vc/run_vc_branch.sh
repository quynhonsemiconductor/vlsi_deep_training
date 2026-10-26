#!/usr/bin/env bash
# Run a sign-off tool on a branch in a fresh clone on the compute node.
# The one runner for every tool (VC Static, DC, PT) — same shape as
# flow/vcs/run_vcs_branch.sh. Run from the working copy on the server.
#   bash run_vc_branch.sh <block> <branch> <lint|cdc|rdc|dc|pt>
set -euo pipefail
block=${1:?block}; branch=${2:?branch}; mode=${3:-lint}
here=$(git rev-parse --show-toplevel)
url=$(git -C "$here" remote get-url origin)
case "$url" in /*) url="file://$url";; esac

case "$mode" in
  lint|cdc|rdc) out_path="vc/$mode";        runner="bash $here/flow/vc/run_vc.sh '$block' '$here/flow/vc' '$mode'" ;;
  dc)           out_path="dc";               runner="bash $here/flow/dc/run_dc.sh '$block' '$here/flow/dc'" ;;
  pt)           out_path="pt";               runner="bash $here/flow/pt/run_pt.sh '$block' '$here/flow/pt'" ;;
  *) echo "unknown mode: $mode"; exit 1 ;;
esac

dir="${QSOC_SCRATCH:-${TMPDIR:-/tmp}}/qsoc_$(echo ${out_path} | tr / _)_${USER:-me}/$block"
rm -rf "$dir"
git clone -q --depth 1 --branch "$branch" "$url" "$dir"
rc=0
(cd "$dir" && eval "$runner") || rc=$?
mkdir -p "$here/build/$out_path/$block"
for f in summary.txt; do
  cp "$dir/build/$out_path/$block/$f" "$here/build/$out_path/$block/" 2>/dev/null || true
done
for d in reports results; do
  cp -r "$dir/build/$out_path/$block/$d" "$here/build/$out_path/$block/" 2>/dev/null || true
done
[ "$rc" -eq 0 ] && echo "PR comment: make ${mode}-post BLOCK=$block PR=<n>"
exit $rc
