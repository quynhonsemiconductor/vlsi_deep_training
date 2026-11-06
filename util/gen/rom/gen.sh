#!/usr/bin/env bash
# Recipe of the boot ROM contents (QNSC_ROM_MAS V3.2 7.2, ROM_006), run by
# flow/gen/gen_ip.sh as: bash util/gen/rom/gen.sh <out_dir>, from the repository root.
#
# Unlike the vendored generators, the input is ours: rom_image.hex, the built
# bootloader (make -C design/rom/boot rtl copies it here). The recipe copies it
# and regenerates m_qnsc_rom_image.sv from it, so make gen-check fails when the
# committed module is not the generation of the committed hex.
set -euo pipefail
out=${1:?usage: gen.sh <out_dir>}
cp util/gen/rom/rom_image.hex "$out/rom_image.hex"
python3 util/gen_rom.py "$out/rom_image.hex" "$out/m_qnsc_rom_image.sv" >/dev/null
