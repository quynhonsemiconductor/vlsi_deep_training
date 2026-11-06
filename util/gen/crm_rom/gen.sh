#!/usr/bin/env bash
# Recipe of the SCRC CRM ROM (QNSC_SCRC_MAS 7.5, 7.6), run by flow/gen/gen_ip.sh as:
#   bash util/gen/crm_rom/gen.sh <out_dir>     from the repository root.
#
# Input: design/scrc/crm/crm_rom.S, the program MCPU runs from 0x1000 after every
# release of w_rst_n_sys. util/gen_crm_rom.py assembles it (only the 13
# instructions MRV-CPU decodes, no RISC-V toolchain) and writes
# m_qnsc_scrc_crm_rom.sv (constant case over the word index, 64 words),
# crm_rom.hex and crm_rom.lst.
set -euo pipefail
out=${1:?usage: gen.sh <out_dir>}
python3 util/gen_crm_rom.py design/scrc/crm/crm_rom.S "$out" >/dev/null
