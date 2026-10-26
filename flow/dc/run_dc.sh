#!/usr/bin/env bash
# Design Compiler synthesis, on a compute node, inside the scratch clone.
#   bash run_dc.sh <block> <scripts-dir>
set -euo pipefail
block=${1:?block}; sdir=${2:?scripts dir}
flist="design/${block}/${block}.f"
[ -f "$flist" ] || { echo "no $flist"; exit 1; }
command -v dc_shell >/dev/null || { echo "load the DC module first"; exit 1; }

top="m_qnsc_wrap_${block}"
grep -qE "(^|/)m_qnsc_wrap_${block}\.sv[[:space:]]*$" "$flist" || \
  top=$(grep -oE 'rtl/[A-Za-z0-9_]+\.sv' "$flist" | tail -1 | xargs -n1 basename | sed 's/\.sv$//')

sdc="design/${block}/constraints/${block}.sdc"
sdc_val=""; [ -f "$sdc" ] && sdc_val="$PWD/$sdc"
if [ -z "$sdc_val" ]; then
  echo "FAIL: synthesis needs design/${block}/constraints/${block}.sdc — none found."
  exit 2
fi

LIBDIR="${QSOC_LIB_DIR:-/tools/pdk_libraries/SMIC/SMIC28NM/SMIC28HKMG/SMIC-28HKMG-7-Track-c31-Standard-Cell-Library/arm/smic/28hkmg/sc7mc_base_svt_c31/r1p0/db}"
LIB="${QSOC_TARGET_LIB:-sc7mc_28hkmg_base_svt_c31_ssg_typical_max_0p72v_m40c.db}"
[ -f "$LIBDIR/$LIB" ] || { echo "FAIL: $LIBDIR/$LIB not found on this node"; exit 2; }

out="build/dc/${block}"
mkdir -p "$out/logs" "$out/reports" "$out/results"

cat > syn_config.tcl <<CFG
set DESIGN_NAME     "$top"
set RTL_FILELIST    "$PWD/$flist"
set DEFINE_LIST     {}
set LIBRARY_DIR     $LIBDIR
set TARGET_LIBRARIES $LIB
set SDC_FILE        "$sdc_val"
set UPF_FILE        ""
set REPORT_DIR      "$out/reports"
set LOG_DIR         "$out/logs"
set OUTPUT_DIR      "$out/results"
set APP_VARS        {}
set MESSAGE_FOR_SUPPRESS {}
set DONT_TOUCH_CELLS {}
set DONT_USE_CELLS   {}
set SIZE_ONLY_CELLS  {}
set CLOCK_GATING_STYLE {}
CFG

echo "== DC synthesis: $block (top $top), lib $LIB"
dc_shell -no_init -f "$sdir/syn.tcl" \
    -output_log_file "$out/logs/dc.log" || true

# summary from the reports
cells=$(grep -m1 "Total cells" "$out/reports/cell_count.rpt" 2>/dev/null | grep -oE '[0-9]+' || echo "?")
regs=$(grep -m1 "Registers" "$out/reports/cell_count.rpt" 2>/dev/null | grep -oE '[0-9]+' || echo "?")
{
  echo "DC_SYN | block $block | top $top | commit $(git rev-parse --short HEAD 2>/dev/null || echo ?)"
  echo "Compiled: $(date '+%Y-%m-%d %H:%M %Z')"
  echo "Cells: $cells | Registers: $regs"
  if [ "$cells" = "?" ]; then
    echo "FAIL: synthesis did not produce reports (check $out/logs/dc.log)"
  elif grep -qiE "^Error" "$out/logs/dc.log" 2>/dev/null; then
    echo "FAIL: DC errors in log (check $out/logs/dc.log)"
  else
    echo "PASS"
  fi
} | tee "$out/summary.txt"
grep -q "^PASS" "$out/summary.txt"
