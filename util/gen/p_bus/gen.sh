#!/usr/bin/env bash
# Recipe of P_BUS (QNSC_PBUS_MAS), run by flow/gen/gen_ip.sh as:
#   bash util/gen/p_bus/gen.sh <out_dir>     from the repository root.
#
# Input: p_bus.xlsx, the APB-BUS-Generator workbook in the format of the mentor's
# APB_BUS_Example.xlsx (CFG, MM-CFG, MM-INFO). One master, AXI2APB, 18-bit
# address (contract meta.pbus_paddr_width); fourteen slaves APB_M0..M13 in
# contract order, 14-bit address each (meta.apb_paddr_width), base n x 0x4000.
# Slots 14 and 15 are not listed, so the decoder's default answers them:
# PREADY = 1, PSLVERR = 1, PRDATA = 0.
#
# The generator (vendor/nguyenquanicd/APB-BUS-Generator, unmodified) writes into
# its working directory, so it runs in a scratch directory and only the RTL is
# kept. What this recipe changes, and why:
#   - the module names: the generator hard-codes m_vlsi_apb_router,
#     m_vlsi_decoder_<master> and m_vlsi_arbiter_<slave>, which break Naming
#     Rule 2.1 and collide with the SCRC internal bus made by the same tool
#     (vendor/manifest.yml). Each becomes m_qnsc_p_bus[_dec|_arb_<slave>], and
#     the file is renamed after it (rule 2.7);
#   - the header line "Author:", which the generator fills with the login of
#     whoever runs it: LOGNAME is fixed so a regeneration is byte-identical;
#   - dropped: Debug/debug.json (carries a timestamp), RTL/filelist.f and
#     source_me.sh (absolute paths of the scratch directory), VC_Waiver/ and the
#     ArbRRBalance copy (one master: every arbiter is plain assignments, none
#     instantiates a round-robin cell). design/pbus/pbus.f lists the files.
set -euo pipefail
out=${1:?usage: gen.sh <out_dir>}
here=util/gen/p_bus
gen=$PWD/vendor/nguyenquanicd/APB-BUS-Generator/apb_rtl_generator.py

cp "$here/p_bus.xlsx" "$out/p_bus.xlsx"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
( cd "$tmp" && LOGNAME=apb-bus-generator python3 "$gen" "$OLDPWD/$here/p_bus.xlsx" MM-INFO >/dev/null )

# old module name -> new; the old name is also the file name (rule 2.7)
rename="s/\bm_vlsi_apb_router\b/m_qnsc_p_bus/g; s/\bm_vlsi_decoder_axi2apb\b/m_qnsc_p_bus_dec/g;"
rename+=" s/\bm_vlsi_arbiter_\([a-z0-9_]*\)\b/m_qnsc_p_bus_arb_\1/g"
for f in "$tmp"/RTL/m_vlsi_apb_router.sv "$tmp"/RTL/Decoder/*.sv "$tmp"/RTL/Arbiter/*.sv; do
  name=$(basename "$f" .sv | sed "$rename")
  sed "$rename" "$f" > "$out/$name.sv"
done
