#!/usr/bin/env bash
# Regenerate every emacs wrapper and fail if the committed file differs.
#
# rtl/<wrapper>.sv is generated from rtl/emacs/<wrapper>.src.sv. A hand edit to
# the generated file, or a .src.sv change committed without running make, would
# leave the compiled wrapper and its source disagreeing -- the same drift the
# qnsc_pkg check stops. Whitespace is ignored, because verilog-mode aligns
# columns slightly differently between emacs versions.
#
# The regenerated files are left in the working tree: locally that is the same
# as running `make wrap` for every block.
set -uo pipefail

if ! command -v emacs >/dev/null 2>&1; then
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "emacs not installed"; exit 1
  fi
  echo "  emacs not installed -- skipped (brew install emacs, or apt install emacs-nox)"
  exit 0
fi

fail=0
found=0
for mk in design/*/rtl/emacs/Makefile; do
  [ -f "$mk" ] || continue
  found=1
  dir=$(dirname "$mk")
  block=$(echo "$dir" | cut -d/ -f2)
  rtl="design/${block}/rtl"
  log="/tmp/wrap-${block}.log"

  if ! make -s -C "$dir" > "$log" 2>&1; then
    printf '  %-10s FAIL (make)\n' "$block"
    sed 's/^/      /' "$log"
    fail=1
    continue
  fi

  # Only generated files are compared; the .src.sv and the Makefile are inputs.
  spec=("$rtl/*.sv" ":(exclude)*.src.sv")
  new=$(git ls-files --others --exclude-standard -- "${spec[@]}")
  diff=$(git diff -w -- "${spec[@]}")
  if [ -n "$new$diff" ]; then
    printf '  %-10s FAIL -- run make in %s and commit the result\n' "$block" "$dir"
    [ -n "$new" ] && echo "$new" | sed 's/^/      not committed: /'
    [ -n "$diff" ] && echo "$diff" | sed 's/^/      /'
    fail=1
  else
    printf '  %-10s ok\n' "$block"
  fi
done

[ "$found" = 0 ] && echo "  no emacs wrapper yet"
exit $fail
