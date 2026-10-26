#!/usr/bin/env bash
# Laptop driver for every server sign-off tool: pushes the branch to the
# server copy, checks out the flow branch, runs the tool on a shade node.
#   QSOC_SERVER=<alias> [VC_FLOW_BRANCH=<b>] TOOL=<vc-lint|vc-cdc|vc-rdc|syn-dc|sta-pt> \
#     BLOCK=<> BRANCH=<> bash flow/signoff.sh
set -euo pipefail
block=${BLOCK:?}; branch=${BRANCH:?}; tool=${TOOL:?}
server=${QSOC_SERVER:?set QSOC_SERVER}
flow_branch=${VC_FLOW_BRANCH:-main}
url="$server:qsoc.git"

git push -q --no-verify -f "$url" "$branch"
git push -q --no-verify -f "$url" "$flow_branch" 2>/dev/null || true

case "$tool" in
  vc-lint)  module="synopsys/vc_static/W-2024.09-SP1"; runner="bash flow/vc/run_vc_branch.sh '$block' '$branch' lint" ;;
  vc-cdc)   module="synopsys/vc_static/W-2024.09-SP1"; runner="bash flow/vc/run_vc_branch.sh '$block' '$branch' cdc"  ;;
  vc-rdc)   module="synopsys/vc_static/W-2024.09-SP1"; runner="bash flow/vc/run_vc_branch.sh '$block' '$branch' rdc"  ;;
  syn-dc)   module="synopsys/fc/W-2024.09-SP3";        runner="bash flow/signoff/run_branch.sh '$block' '$branch' dc"  ;;
  sta-pt)   module="synopsys/prime/W-2024.09-SP3";     runner="bash flow/signoff/run_branch.sh '$block' '$branch' pt"  ;;
  *) echo "unknown TOOL: $tool"; exit 1 ;;
esac

ssh -o BatchMode=yes "$server" "
  set -e
  cd ~/${QSOC_SERVER_REPO:-vlsi_deep_training}
  git fetch -q origin
  git checkout -q '$flow_branch'
  git reset -q --hard 'origin/$flow_branch'
  srun --partition=shade --nodes=1 --time=60:00 --job-name=so-$tool bash -lc \"
    source /etc/profile.d/modules.sh 2>/dev/null
    module load $module
    $runner\"
" 2>&1 | grep -v 'WARNING\|post-quantum\|upgraded\|^\*\*'

# Evidence: pull summary from server into design/<block>/<stage>/
stage=${tool#vc-}
[ "$stage" = "$tool" ] && stage=$tool
[ "$tool" = syn-dc ] && stage=syn
[ "$tool" = sta-pt ] && stage=sta
evdir="design/${block}/${stage}"
mkdir -p "$evdir"
sp="build/vc/${stage}/${block}/summary.txt"
[ "$tool" = syn-dc ] && sp="build/dc/${block}/summary.txt"
[ "$tool" = sta-pt ] && sp="build/pt/${block}/summary.txt"
ssh -o BatchMode=yes "$server" "cat ~/${QSOC_SERVER_REPO:-vlsi_deep_training}/$sp 2>/dev/null" 2>/dev/null > "$evdir/summary.txt" || true
[ -s "$evdir/summary.txt" ] && echo "evidence: $evdir/summary.txt" || { rm -f "$evdir/summary.txt"; echo "no summary found on server"; }
