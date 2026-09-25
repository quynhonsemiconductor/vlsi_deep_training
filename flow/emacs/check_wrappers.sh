#!/usr/bin/env bash
# Regenerate every emacs wrapper and fail if the committed file differs.
#
# The AUTO blocks of rtl/<wrapper>.sv are written by emacs, either in place or
# from rtl/emacs/<wrapper>.src.sv (flow/emacs/wrap.mk). A hand edit inside an
# AUTO block, or an AUTO comment or template changed without running make,
# would leave the compiled wrapper and its source disagreeing -- the same drift
# the qnsc_pkg check stops. Whitespace is ignored, because verilog-mode aligns
# columns slightly differently between emacs versions.
#
# The regenerated files are left in the working tree: locally that is the same
# as running `make wrap` for every block.
set -uo pipefail

# emacs is needed only once a wrapper exists; then its absence is a failure,
# not a skip, or an unregenerated wrapper would pass.
if ! ls design/*/rtl/emacs/Makefile >/dev/null 2>&1; then
  echo "  no emacs wrapper yet"; exit 0
fi
command -v emacs >/dev/null 2>&1 || {
  echo "emacs not installed (brew install emacs, or apt install emacs-nox)"; exit 1; }

fail=0
for mk in design/*/rtl/emacs/Makefile; do
  [ -f "$mk" ] || continue
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

  # Only the two generated files are compared: the copy in rtl/emacs/ and the
  # one in rtl/. The .src.sv, the Makefile and hand-written rtl/ files are not.
  design=$(sed -nE 's/^DESIGN[[:space:]]*=[[:space:]]*([A-Za-z0-9_]+).*/\1/p' "$mk" | head -1)
  spec=("$dir/$design.sv" "$rtl/$design.sv")
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

exit $fail
