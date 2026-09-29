#!/usr/bin/env bash
# One-time setup of your repository copy on the training server. Run on YOUR machine.
#
#   QSOC_SERVER=<ssh alias> make server-setup
#
# Creates, in YOUR server home (every account has its own, private):
#   ~/qsoc.git            a bare repository your machine pushes to
#   ~/vlsi_deep_training  your working copy, cloned from it, on main
# and adds the remote `server` to this clone. Names are fixed so that every
# command in the guides is the same for everyone. Safe to run again: what exists
# is kept. The server cannot reach GitHub, so code goes one way: here -> server.
set -euo pipefail
server=${QSOC_SERVER:?set QSOC_SERVER to the ssh alias of the training server}
remote=${QSOC_SERVER_REMOTE:-server}
name=$(git config user.name || true); email=$(git config user.email || true)
[ -n "$name" ] && [ -n "$email" ] || { echo "set git user.name and user.email first (git config --global ...)"; exit 1; }
command -v ssh >/dev/null || { echo "ssh not found: on Windows, run this in WSL (README, Getting started)"; exit 1; }

echo "== server: bare repository and working copy"
ssh "$server" bash -s -- "$name" "$email" <<'REMOTE'
set -e
[ -d ~/qsoc.git ] || { mkdir -p ~/qsoc.git; git init -q --bare ~/qsoc.git; }
git -C ~/qsoc.git symbolic-ref HEAD refs/heads/main
echo "~/qsoc.git ready"
REMOTE

echo "== this clone: remote '$remote'"
if git remote get-url "$remote" >/dev/null 2>&1; then
  git remote set-url "$remote" "$server:qsoc.git"
else
  git remote add "$remote" "$server:qsoc.git"
fi
git fetch -q origin
git push -q --no-verify "$remote" origin/main:refs/heads/main     # main as CI checked it

ssh "$server" bash -s -- "$name" "$email" <<'REMOTE'
set -e
w=~/vlsi_deep_training
if [ ! -d "$w/.git" ]; then
  # a network home may refuse a fresh directory once; try again before giving up
  for i in 1 2 3; do rm -rf "$w"; git clone -q ~/qsoc.git "$w" 2>/dev/null && break; sleep 1; done
fi
git -C "$w" fetch -q origin
git -C "$w" checkout -q main 2>/dev/null || git -C "$w" checkout -q -B main origin/main
# bring main up to date; never touch local work
if git -C "$w" diff --quiet && git -C "$w" diff --cached --quiet; then
  git -C "$w" merge -q --ff-only origin/main 2>/dev/null || echo "note: ~/vlsi_deep_training main has local commits; left as is"
else
  echo "note: ~/vlsi_deep_training has uncommitted changes; main not updated"
fi
git -C "$w" config user.name "$1"; git -C "$w" config user.email "$2"
echo "~/vlsi_deep_training ready at $(git -C "$w" log -1 --format=%h)"
REMOTE

echo "done. Per PR: git push $remote <branch>; then the five steps in doc/guides/GETTING_STARTED.md"
