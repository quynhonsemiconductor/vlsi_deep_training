#!/usr/bin/env bash
# Post the summary of a server VCS compile as a comment on a pull request.
# Runs on YOUR machine (the server cannot reach GitHub): it reads the one small
# text file run_vcs wrote on the server over SSH, and posts it with gh.
#
#   QSOC_SERVER=<ssh alias> make vcs-post BLOCK=<block> PR=<number> [DRY=1]
#
# QSOC_SERVER is the Host alias of the training server in your ~/.ssh/config;
# QSOC_SERVER_REPO is your repository copy there (default: vlsi_deep_training, in
# your home). Only summary.txt leaves the server: tool versions, our own file
# names and counts -- nothing from the vendor's libraries.
set -euo pipefail
block=${1:?usage: post_summary.sh <block> <pr>}
pr=${2:?usage: post_summary.sh <block> <pr>}
server=${QSOC_SERVER:?set QSOC_SERVER to the ssh alias of the training server}
repo=${QSOC_SERVER_REPO:-vlsi_deep_training}

summary=$(ssh -o BatchMode=yes "$server" "cat '$repo/build/vcs/$block/summary.txt'" 2>/dev/null) \
  || { echo "no build/vcs/$block/summary.txt on $server: run make vcs BLOCK=$block there first"; exit 1; }
there=$(sed -nE '1s/.*commit ([0-9a-f]+).*/\1/p' <<< "$summary")
head=$(gh pr view "$pr" --json headRefOid --jq .headRefOid)
case "$head" in "$there"*) ;; *)
  echo "the server compiled $there, but PR #$pr is at ${head:0:7}: push that commit to the server, compile, then post"
  exit 1;; esac

result=PASS
grep -qE '^FAIL|^Error-: [1-9]' <<< "$summary" && result=FAIL
title="**VCS compile on the training server**"
branch=$(gh pr view "$pr" --json headRefName --jq .headRefName)
body=$(printf '%s: %s\n\nReproduce on the server: `make vcs-branch BLOCK=%s BRANCH=%s`\n\n```\n%s\n```\n' \
       "$title" "$result" "$block" "$branch" "$summary")
[ -n "${DRY:-}" ] && { printf '%s\n' "$body"; exit 0; }

# One summary comment per PR: update yours if it exists, so the PR shows the latest
# compile only (GitHub keeps the edit history).
repo_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
me=$(gh api user --jq .login)
id=$(gh api "repos/$repo_slug/issues/$pr/comments" --paginate \
       --jq ".[] | select(.user.login == \"$me\" and (.body | startswith(\"$title\"))) | .id" | tail -1)
if [ -n "$id" ]; then
  gh api -X PATCH "repos/$repo_slug/issues/comments/$id" -f body="$body" --jq .html_url
else
  gh pr comment "$pr" --body "$body"
fi
