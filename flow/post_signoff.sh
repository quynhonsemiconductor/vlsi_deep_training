#!/usr/bin/env bash
# Post any sign-off summary as a comment on a PR. One comment per tool per PR,
# edited in place -- the same contract as the VCS summary.
#   QSOC_SERVER=<alias> make <tool>-post BLOCK=<> PR=<>
set -euo pipefail
block=${1:?block}; pr=${2:?pr}; tool=${3:?tool}
server=${QSOC_SERVER:?set QSOC_SERVER}
repo=${QSOC_SERVER_REPO:-vlsi_deep_training}

case "$tool" in
  vc-lint)  title="**VC Static LINT on the training server**";        src="vc/lint/$block" ;;
  vc-cdc)   title="**VC Static CDC on the training server**";         src="vc/cdc/$block"  ;;
  vc-rdc)   title="**VC Static RDC on the training server**";         src="vc/rdc/$block"  ;;
  syn-dc)   title="**Design Compiler SYN on the training server**";   src="dc/$block"      ;;
  sta-pt)   title="**PrimeTime STA on the training server**";         src="pt/$block"      ;;
  *) echo "unknown tool: $tool"; exit 1 ;;
esac

summary=$(ssh -o BatchMode=yes "$server" "cat '$repo/build/$src/summary.txt'" 2>/dev/null) \
  || { echo "no build/$src/summary.txt on $server: run make first"; exit 1; }
there=$(sed -nE '1s/.*commit ([0-9a-f]+).*/\1/p' <<< "$summary")
head=$(gh pr view "$pr" --json headRefOid --jq .headRefOid)
case "$head" in "$there"*) ;; *)
  echo "server has $there but PR #$pr is at ${head:0:7}: rerun"; exit 1;; esac
result=$(grep -qE '^PASS' <<< "$summary" && echo PASS || echo FAIL)
branch=$(gh pr view "$pr" --json headRefName --jq .headRefName)
body=$(printf '%s: %s\n\nReproduce on the server: `make %s BLOCK=%s BRANCH=%s`\n\n```\n%s\n```\n' \
  "$title" "$result" "$tool" "$block" "$branch" "$summary")
repo_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
me=$(gh api user --jq .login)
id=$(gh api "repos/$repo_slug/issues/$pr/comments" --paginate \
      --jq ".[] | select(.user.login == \"$me\" and (.body | startswith(\"$title\"))) | .id" | tail -1)
if [ -n "$id" ]; then gh api -X PATCH "repos/$repo_slug/issues/comments/$id" -f body="$body" --jq .html_url
else gh pr comment "$pr" --body "$body"; fi
