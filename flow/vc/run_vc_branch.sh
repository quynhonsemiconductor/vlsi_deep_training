#!/usr/bin/env bash
# LINT a branch with VC Static in a fresh clone on the compute node's local
# disk, the same shape as flow/vcs/run_vcs_branch.sh. Run from the working
# copy on the server; the scripts come from THIS checkout's flow/vc.
set -euo pipefail
block=${1:?block}; branch=${2:?branch}
here=$(git rev-parse --show-toplevel)
url=$(git -C "$here" remote get-url origin)
case "$url" in /*) url="file://$url";; esac
dir="${QSOC_SCRATCH:-${TMPDIR:-/tmp}}/qsoc_vc_${USER:-me}/$block"
rm -rf "$dir"
git clone -q --depth 1 --branch "$branch" "$url" "$dir"
rc=0
(cd "$dir" && bash "$here/flow/vc/run_vc.sh" "$block" "$here/flow/vc") || rc=$?
mkdir -p "$here/build/vc/$block"
cp "$dir/build/vc/$block/summary.txt" "$here/build/vc/$block/" 2>/dev/null || true
cp -r "$dir/build/vc/$block/reports" "$here/build/vc/$block/" 2>/dev/null || true
cp "$dir/build/vc/$block/logs/screen.log" "$here/build/vc/$block/" 2>/dev/null || true
[ "$rc" -eq 0 ] && echo "PR comment, from your machine: QSOC_SERVER=<alias> make vc-post BLOCK=$block PR=<number>"
exit $rc
