#!/usr/bin/env bash
# Verilator lint, one invocation per block so a failure names the block -- and
# therefore names the owner, through CODEOWNERS.
#
# The file list comes from design/<block>/<block>.f, never from `find`. Three
# reasons, all of them already true in this repository:
#
#   1. A wrapper instantiates upstream IP that lives under vendor/, which `find
#      design/<block>` cannot see -- lint would report the IP as undefined.
#   2. Vendor trees contain modules that share a name on purpose, as mutually
#      exclusive alternatives: riscv-dbg defines dmi_jtag_tap in both
#      dmi_jtag_tap.sv and dmi_bscane_tap.sv, and OpenTitan defines
#      tlul_adapter_vh twice. Verilog has one flat module namespace, so exactly
#      one of each pair may be compiled. Only an explicit list can choose.
#   3. Compile order matters -- a package must precede the modules that import
#      it -- and `find` returns alphabetical order.
#
# A block whose filelist has no source lines yet is skipped rather than failed,
# so this is useful from the first commit instead of only once every block exists.
set -uo pipefail

# An optional argument lints one block: bash flow/lint/lint_all.sh pwm
if [ $# -gt 0 ]; then dirs="design/$1/"; else dirs="design/*/"; fi

fail=0
for dir in $dirs; do
  block=$(basename "$dir")
  flist="${dir}${block}.f"

  if [ ! -f "$flist" ]; then
    printf '  %-10s no %s.f -- add one, see design/%s/%s.f in another block\n' \
           "$block" "$block" "$block" "$block"
    fail=1
    continue
  fi

  # Source lines are the non-comment, non-blank ones.
  if ! grep -qvE '^\s*(#|//|$)' "$flist"; then
    printf '  %-10s filelist empty, skipped\n' "$block"
    continue
  fi

  waiver=""
  [ -f "${dir}waivers.vlt" ] && waiver="${dir}waivers.vlt"

  # -F, not -f: paths inside the filelist are relative to the filelist itself
  # (../../vendor/...), and -f would resolve them against the repository root.
  # The log is written first and grepped second: with pipefail, piping verilator
  # into grep took verilator's non-zero exit as the result and reported "ok".
  log="/tmp/lint-${block}.log"
  verilator --lint-only -Wall -Wno-fatal $waiver -F "$flist" > "$log" 2>&1
  # A filelist that holds only packages (design/top today: qnsc_pkg.sv) has no
  # module to elaborate. Verilator 5.020, the Ubuntu package CI installs, stops
  # with "No top level module found"; newer releases accept it. Not a defect.
  if [ "$(grep -c '%Error' "$log")" -le 2 ] && grep -q 'No top level module found' "$log"; then
    printf '  %-10s no module yet, skipped\n' "$block"
    continue
  fi
  if grep -q '%Error' "$log"; then
    printf '  %-10s FAIL\n' "$block"
    sed 's/^/      /' "$log"
    fail=1
  else
    printf '  %-10s ok\n' "$block"
  fi
done
exit $fail
