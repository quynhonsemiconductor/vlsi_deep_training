#!/usr/bin/env bash
# Recipe of the IO MUX (design/iomux), run by flow/gen/gen_ip.sh as:
#   bash util/gen/iomux/gen.sh <out_dir>     from the repository root.
#
# Input: iomux_pads.yml, the pin map and function catalog (README.md). It is
# copied into <out_dir> so that `make gen` keeps it.
#
#   1. util/gen_iomux.py checks the table and writes m_qnsc_iomux_mux.sv,
#      iomux_expect.svh and the APB-CSR-Generator workbook (scratch only: an
#      .xlsx is not byte-reproducible, the table is the source).
#   2. The vendored generator (vendor/nguyenquanicd/APB-CSR-Generator,
#      unmodified) writes RTL/ and Debug/ into its working directory, so it runs
#      in a scratch directory and only m_qnsc_iomux_csr.sv is kept. The header
#      lines "Generator:" (LOGNAME fixed) and "Date and time:" (replaced) are
#      made constant, so a regeneration is byte-identical. Dropped:
#      RTL/models/m_vlsi_synch.sv (synchronous bus, not instantiated),
#      RTL/filelist.f (absolute paths), Debug/debug.json.
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1   # the generator is vendored: write nothing into vendor/
out=${1:?usage: gen.sh <out_dir>}
here=util/gen/iomux
gen=$PWD/vendor/nguyenquanicd/APB-CSR-Generator/CSR_Generation.py

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cp "$here/iomux_pads.yml" "$tmp/iomux_pads.yml"   # $out may be $here
python3 util/gen_iomux.py "$tmp/iomux_pads.yml" "$out" "$tmp/iomux_csr.xlsx" >/dev/null
cp "$tmp/iomux_pads.yml" "$out/iomux_pads.yml"

( cd "$tmp" && LOGNAME=apb-csr-generator USER=apb-csr-generator python3 "$gen" iomux_csr.xlsx IOMUXCSR >/dev/null )
sed 's#^// Date and time: .*#// Date and time: fixed by util/gen/iomux/gen.sh#' \
  "$tmp/RTL/m_qnsc_iomux_csr.sv" > "$out/m_qnsc_iomux_csr.sv"
