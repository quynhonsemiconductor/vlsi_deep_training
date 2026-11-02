#!/usr/bin/env bash
# Recipe of the SCRC CSR (QNSC_SCRC_MAS 6), run by flow/gen/gen_ip.sh as:
#   bash util/gen/scrc_csr/gen.sh <out_dir>     from the repository root.
#
# Input: scrc_csr.xlsx, the APB-CSR-Generator workbook, sheet SCRCCSR (module
# m_qnsc_scrc_csr): SW_RST 0x00, CLK_EN 0x04, ICG_EN 0x0C, RST_REL 0x10,
# APB_BLK 0x14, APB_BUSY 0x18, one field per domain bit (README.md).
#
# The generator (vendor/nguyenquanicd/APB-CSR-Generator, unmodified) writes RTL/
# and Debug/ into its working directory, so it runs in a scratch directory and only
# the module is kept. What this recipe changes, and why:
#   - the header lines "Generator:" (the login of whoever runs it; LOGNAME is
#     fixed) and "Date and time:" (replaced by a fixed text), so a regeneration
#     is byte-identical;
#   - dropped: RTL/models/m_vlsi_synch.sv (the workbook selects the synchronous
#     bus, which does not instantiate it), RTL/filelist.f (absolute paths),
#     Debug/debug.json.
set -euo pipefail
out=${1:?usage: gen.sh <out_dir>}
here=util/gen/scrc_csr
gen=$PWD/vendor/nguyenquanicd/APB-CSR-Generator/CSR_Generation.py

cp "$here/scrc_csr.xlsx" "$out/scrc_csr.xlsx"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" && LOGNAME=apb-csr-generator USER=apb-csr-generator python3 "$gen" "$OLDPWD/$here/scrc_csr.xlsx" SCRCCSR >/dev/null )

sed 's#^// Date and time: .*#// Date and time: fixed by util/gen/scrc_csr/gen.sh#' \
  "$tmp/RTL/m_qnsc_scrc_csr.sv" > "$out/m_qnsc_scrc_csr.sv"
