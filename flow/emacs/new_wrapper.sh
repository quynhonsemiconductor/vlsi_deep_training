#!/usr/bin/env bash
# Scaffold design/<block>/rtl/emacs/ for a wrapper generated with emacs.
#
#   bash flow/emacs/new_wrapper.sh <block> <path to the IP top-level .sv>
#   make new-wrap BLOCK=pwm IP=vendor/pulp-platform/apb_adv_timer/rtl/apb_adv_timer.sv
#
# Writes three files and nothing else:
#   Makefile             DESIGN = m_qnsc_wrap_<ip_module>, includes flow/emacs/wrap.mk
#   filelist_emacs.f     the IP file, so verilog-mode can read its ports
#   <design>.src.sv      flow/emacs/template.src.sv with the names filled in
# Then fill the AUTO_TEMPLATE and run `make wrap BLOCK=<block>`.
set -euo pipefail

block="${1:?usage: new_wrapper.sh <block> <ip_top.sv>}"
ip="${2:?usage: new_wrapper.sh <block> <ip_top.sv>}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
dir="$repo/design/$block/rtl/emacs"

[ -d "$repo/design/$block" ] || { echo "no design/$block"; exit 1; }
[ -f "$repo/$ip" ] || { echo "no $ip (give the path from the repository root)"; exit 1; }
module=$(sed -nE 's/^[[:space:]]*module[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\1/p' "$repo/$ip" | head -1)
[ -n "$module" ] || { echo "no module found in $ip"; exit 1; }

# Naming Rule 2.1: a wrapper is m_qnsc_wrap_<ip_module>.
design="m_qnsc_wrap_$module"
[ -e "$dir/$design.src.sv" ] && { echo "$dir/$design.src.sv exists -- not overwritten"; exit 1; }

mkdir -p "$dir"
printf 'DESIGN = %s\n\ninclude ../../../../flow/emacs/wrap.mk\n' "$design" > "$dir/Makefile"
printf '../../../../%s\n' "$ip" > "$dir/filelist_emacs.f"
upper=$(echo "$block" | tr '[:lower:]' '[:upper:]')
sed -e "s/@DESIGN@/$design/g" -e "s/@IP_MODULE@/$module/g" \
    -e "s/@BLOCK_UPPER@/$upper/g" -e "s/@BLOCK@/$block/g" \
    "$here/template.src.sv" > "$dir/$design.src.sv"

echo "wrote design/$block/rtl/emacs/{Makefile, filelist_emacs.f, $design.src.sv}"
echo "next: fill the AUTO_TEMPLATE for $module, then make wrap BLOCK=$block"
