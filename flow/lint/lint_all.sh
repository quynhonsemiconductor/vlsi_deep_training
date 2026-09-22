#!/usr/bin/env bash
# Verilator lint, one invocation per block so a failure names the block.
#
# A block with no .sv yet is skipped, not failed: this has to be useful from the
# first commit rather than only once all sixteen blocks exist.
#
# --timing is off and -Wall is on. The waivers live per block in
# flow/lint/waivers/<block>.vlt so that a waiver is attributable to an owner
# rather than accumulating in one shared file nobody reads.
set -uo pipefail

fail=0
for dir in design/*/; do
  block=$(basename "$dir")
  files=$(find "$dir" -name '*.sv' -o -name '*.v' 2>/dev/null | sort)
  [ -z "$files" ] && { printf '  %-10s no RTL yet, skipped\n' "$block"; continue; }

  waiver=""
  [ -f "flow/lint/waivers/${block}.vlt" ] && waiver="flow/lint/waivers/${block}.vlt"

  # -I paths let a wrapper include vendored headers without copying them.
  if verilator --lint-only -Wall -Wno-fatal \
       -Ivendor -Idesign/top/rtl \
       $waiver $files 2>&1 | tee "/tmp/lint-${block}.log" | grep -q '%Error'; then
    printf '  %-10s FAIL\n' "$block"; sed 's/^/      /' "/tmp/lint-${block}.log"; fail=1
  else
    printf '  %-10s ok\n' "$block"
  fi
done
exit $fail
