#!/usr/bin/env bash
# Laptop driver: one command end to end. Pushes BRANCH and the flow scripts to
# the server, then runs the LINT on a compute node through Slurm.
#   QSOC_SERVER=<alias> [VC_FLOW_BRANCH=<branch>] make vc-lint BLOCK=<> BRANCH=<>
set -euo pipe fail 2>/dev/null || set -euo pipefail
block=${BLOCK:?}; branch=${BRANCH:?}
server=${QSOC_SERVER:?set QSOC_SERVER}
flow_branch=${VC_FLOW_BRANCH:-main}
git push -q --no-verify -f "$server" "$branch" 2>/dev/null || git push -q --no-verify -f "$server" "$branch"
git push -q --no-verify -f "$server" "$flow_branch" 2>/dev/null || true
ssh -o BatchMode=yes "$server" "
  set -e
  cd ~/${QSOC_SERVER_REPO:-vlsi_deep_training}
  git fetch -q origin
  git checkout -q '$flow_branch'
  git reset -q --hard 'origin/$flow_branch'
  srun --partition=shade --nodes=1 --time=30:00 --job-name=vc-lint bash -lc \"
    source /etc/profile.d/modules.sh 2>/dev/null
    module load synopsys/vc_static/W-2024.09-SP1
    bash flow/vc/run_vc_branch.sh '$block' '$branch'\"
" 2>&1 | grep -v 'WARNING\|post-quantum\|upgraded\|^\*\*'
