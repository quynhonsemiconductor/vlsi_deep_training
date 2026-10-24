#!/usr/bin/env bash
# Post the VC Static LINT summary as a comment on a pull request; one comment
# per PR, edited in place -- the same contract as the VCS summary.
set -euo pipefail
block=${1:?block}; pr=${2:?pr}
server=${QSOC_SERVER:?set QSOC_SERVER}
repo=${QSOC_SERVER_REPO:-vlsi_deep_training}
summary=$(ssh -o BatchMode=yes "$server" "cat '$repo/build/vc/$block/summary.txt'" 2>/dev/null) \
  || { echo "no build/vc/$block/summary.txt on $server: run make vc-lint first"; exit 1; }
there=$(sed -nE '1s/.*commit ([0-9a-f]+).*/\1/p' <<< "$summary")
head=$(gh pr view "$pr" --json headRefOid --jq .headRefOid)
case "$head" in "$there"*) ;; *)
  echo "server linted $there but PR #$pr is at ${head:0:7}: rerun make vc-lint"; exit 1;; esac
result=$(grep -qE '^PASS' <<< "$summary" && echo PASS || echo FAIL)
title="**VC Static LINT on the training server**"
branch=$(gh pr view "$pr" --json headRefName --jq .headRefName)
body=$(printf '%s: %s\n\nReproduce on the server: `make vc-lint BLOCK=%s BRANCH=%s` (needs synopsys/vc_static on a shade node)\n\n```\n%s\n```\n' \
  "$title" "$result" "$block" "$branch" "$summary")
repo_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
me=$(gh api user --jq .login)
id=$(gh api "repos/$repo_slug/issues/$pr/comments" --paginate \
      --jq ".[] | select(.user.login == \"$me\" and (.body | startswith(\"$title\"))) | .id" | tail -1)
if [ -n "$id" ]; then gh api -X PATCH "repos/$repo_slug/issues/comments/$id" -f body="$body" --jq .html_url
else gh pr comment "$pr" --body "$body"; fi
