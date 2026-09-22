#!/usr/bin/env bash
# Two rules about vendor/, both learned the hard way on this project.
#
# 1. Vendored IP is not edited in place. It is vendored rather than submoduled so
#    that tape-out has a frozen, auditable source -- which only holds if the tree
#    matches upstream. A local edit is invisible at the next bump, when it is
#    silently reverted. Real changes go in vendor/patches/ with a reason.
#
# 2. A change under vendor/ must move vendor/manifest.yml in the same commit.
#    Every upstream fact this project relies on is commit-specific: riscv-dbg's
#    IdcodeValue, aon_timer's five outputs, apb_timer_unit's MODE_64. A bump that
#    does not record the new commit makes all of them unverifiable.
set -uo pipefail
base="${1:-HEAD~1}"

changed=$(git diff --name-only "$base"...HEAD -- vendor/ || true)
[ -z "$changed" ] && { echo "  vendor/ untouched"; exit 0; }

# patches/ and the manifest are the two things allowed to change.
edits=$(echo "$changed" | grep -v '^vendor/patches/' | grep -v '^vendor/manifest.yml$' || true)

if [ -n "$edits" ] && ! echo "$changed" | grep -q '^vendor/manifest.yml$'; then
  echo "  FAIL: vendored IP changed without updating vendor/manifest.yml"
  echo "$edits" | sed 's/^/      /'
  echo
  echo "  If this is an upstream bump: update manifest.yml in the same PR."
  echo "  If this is a local fix:      put it in vendor/patches/ instead."
  exit 1
fi
echo "  vendor/ change accompanied by a manifest update"
