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
  lint|cdc|rdc) dir_name="vc_${mode}"; runner="bash $here/flow/vc/run_vc.sh '$block' '$here/flow/vc' '$mode'" ;;
  dc)           dir_name="dc";        runner="bash $here/flow/dc/run_dc.sh '$block' '$here/flow/dc'" ;;
  pt)           dir_name="pt";        runner="bash $here/flow/pt/run_pt.sh '$block' '$here/flow/pt'" ;;
  *) echo "unknown mode: $mode"; exit 1 ;;
esac

dir="${QSOC_SCRATCH:-${TMPDIR:-/tmp}}/qsoc_${dir_name}_${USER:-me}/$block"
rm -rf "$dir"
git clone -q --depth 1 --branch "$branch" "$url" "$dir"
rc=0
(cd "$dir" && eval "$runner") || rc=$?
mkdir -p "$here/build/$dir_name/$block"
for f in summary.txt; do
  cp "$dir/build/$dir_name/$block/$f" "$here/build/$dir_name/$block/" 2>/dev/null || true
done
for d in reports results; do
  cp -r "$dir/build/$dir_name/$block/$d" "$here/build/$dir_name/$block/" 2>/dev/null || true
done
[ "$rc" -eq 0 ] && echo "PR comment: make ${mode}-post BLOCK=$block PR=<n>"
exit $rc
