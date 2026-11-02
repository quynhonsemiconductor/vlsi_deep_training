#!/usr/bin/env bash
# Recipe of the SCRC internal APB BUS (QNSC_SCRC_MAS 3, 7.4), run by
# flow/gen/gen_ip.sh as:  bash util/gen/scrc_bus/gen.sh <out_dir>  from the root.
#
# Input: scrc_apb_bus.xlsx, the APB-BUS-Generator workbook (CFG, MM-CFG, MM-INFO;
# its content is listed in README.md). Two masters, MCPU and IBEX (P_BUS APB_M0),
# 14-bit address each (contract meta.apb_paddr_width); one slave, SCRC_CSR,
# 5-bit address at 0x00. Offsets 0x0020..0x3FFF hit no slave, so the decoder
# answers them: PREADY = 1, PSLVERR = 1, PRDATA = 0.
#
# The generator (vendor/nguyenquanicd/APB-BUS-Generator, unmodified) writes into
# its working directory, so it runs in a scratch directory and only the RTL is
# kept. What this recipe changes, and why:
#   - the module names: the generator hard-codes m_vlsi_apb_router,
#     m_vlsi_decoder_<master>, m_vlsi_arbiter_<slave> and copies ArbBalanceRR,
#     which break Naming Rule 2.1 and collide with P_BUS, made by the same tool.
#     Each becomes m_qnsc_scrc_apb_bus[_dec_<master>|_arb_csr|_rr], and the file
#     is renamed after it (rule 2.7);
#   - the header line "Author:", which the generator fills with the login of
#     whoever runs it: LOGNAME is fixed so a regeneration is byte-identical;
#   - dropped: Debug/debug.json (carries a timestamp), RTL/filelist.f and
#     source_me.sh (absolute paths of the scratch directory), VC_Waiver/, and the
#     ArbRRBalance cells other than ArbBalanceRR. design/scrc/scrc.f lists the files.
set -euo pipefail
out=${1:?usage: gen.sh <out_dir>}
here=util/gen/scrc_bus
gen=$PWD/vendor/nguyenquanicd/APB-BUS-Generator/apb_rtl_generator.py

cp "$here/scrc_apb_bus.xlsx" "$out/scrc_apb_bus.xlsx"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" && LOGNAME=apb-bus-generator USER=apb-bus-generator python3 "$gen" "$OLDPWD/$here/scrc_apb_bus.xlsx" MM-CFG >/dev/null )

rename="s/\bm_vlsi_apb_router\b/m_qnsc_scrc_apb_bus/g;"
rename+=" s/\bm_vlsi_decoder_\([a-z0-9_]*\)\b/m_qnsc_scrc_apb_bus_dec_\1/g;"
rename+=" s/\bm_vlsi_arbiter_scrc_csr\b/m_qnsc_scrc_apb_bus_arb_csr/g;"
rename+=" s/\bArbBalanceRR\b/m_qnsc_scrc_apb_bus_rr/g"
for f in "$tmp"/RTL/m_vlsi_apb_router.sv "$tmp"/RTL/Decoder/*.sv "$tmp"/RTL/Arbiter/*.sv; do
  name=$(basename "$f" .sv | sed "$rename")
  sed "$rename" "$f" > "$out/$name.sv"
done
sed "$rename" "$tmp/RTL/ArbRRBalance/ArbBalanceRR.v" > "$out/m_qnsc_scrc_apb_bus_rr.v"
