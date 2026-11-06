#!/usr/bin/env bash
# Recipe of the IO MUX (design/iomux), run by flow/gen/gen_ip.sh as:
#   bash util/gen/iomux/gen.sh <out_dir>     from the repository root.
#
# Input: iomux_pads.yml, the pin map and function catalog (README.md). It is
# copied into <out_dir> so that `make gen` keeps it. util/gen_iomux.py checks
# the table and writes m_qnsc_iomux_mux.sv and iomux_expect.svh.
#
# The select register (IOMUX_SEL) is not generated here: it is a register of
# SYSCSR (Pad List v3, 2026-11-04).
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
out=${1:?usage: gen.sh <out_dir>}
here=util/gen/iomux

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp "$here/iomux_pads.yml" "$tmp/iomux_pads.yml"   # $out may be $here
python3 util/gen_iomux.py "$tmp/iomux_pads.yml" "$out" >/dev/null
cp "$tmp/iomux_pads.yml" "$out/iomux_pads.yml"
