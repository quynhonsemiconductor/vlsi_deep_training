#!/usr/bin/env bash
# PrimeTime STA on a compute node, inside the scratch clone.
#   bash run_pt.sh <block> <scripts-dir>
# Requires build/dc/<block>/results/ (from a prior run_dc.sh in the same clone).
set -euo pipefail
block=${1:?block}; sdir=${2:?scripts dir}
command -v pt_shell >/dev/null || { echo "load module synopsys/prime first"; exit 1; }

top="m_qnsc_wrap_${block}"
syn_out="build/dc/${block}/results"
netlist="${syn_out}/${top}.mapped.v"
sdc="${syn_out}/${top}.mapped.sdc"
if [ ! -f "$netlist" ] || [ ! -f "$sdc" ]; then
  echo "FAIL: STA needs the DC netlist + mapped SDC in $syn_out/"
  echo "      run make syn-dc first, on the same branch"
  exit 2
fi

LIBDIR="${QSOC_LIB_DIR:-/tools/pdk_libraries/SMIC/SMIC28NM/SMIC28HKMG/SMIC-28HKMG-7-Track-c31-Standard-Cell-Library/arm/smic/28hkmg/sc7mc_base_svt_c31/r1p0/db}"
LIB="${QSOC_TARGET_LIB:-sc7mc_28hkmg_base_svt_c31_ssg_typical_max_0p72v_m40c.db}"
[ -f "$LIBDIR/$LIB" ] || { echo "FAIL: $LIBDIR/$LIB not found on this node"; exit 2; }

out="build/pt/${block}"
mkdir -p "$out/logs" "$out/reports"

cat > pt_config.tcl <<CFG
set DESIGN_NAME     "$top"
set NETLIST_FILE    "$PWD/$netlist"
set SDC_FILE        "$PWD/$sdc"
set LIBRARY_DIR     $LIBDIR
set LINK_LIBRARIES $LIB
set REPORT_DIR      "$out/reports"
set LOG_DIR         "$out/logs"
set OUTPUT_DIR      "$out"
set APP_VARS        {}
set MESSAGE_FOR_SUPPRESS {}
set MAX_PATHS       100
set NWORST_PATHS    100
CFG

echo "== PT STA: $block (top $top)"
pt_shell -no_init -f "$sdir/pt.tcl" \
    -output_log_file "$out/logs/pt.log" || true

wns=$(grep -m1 "data arrival time" "$out/reports/timing_setup.rpt" 2>/dev/null | head -1 || echo "?")
viol=$(grep -cE "slack.*VIOLATED" "$out/reports/timing_setup.rpt" 2>/dev/null || echo "0")
{
  echo "PT_STA | block $block | top $top | commit $(git rev-parse --short HEAD 2>/dev/null || echo ?)"
  echo "Compiled: $(date '+%Y-%m-%d %H:%M %Z')"
  echo "Setup violations: $viol paths"
  if [ "$viol" = "?" ] || [ ! -f "$out/reports/timing_setup.rpt" ]; then
    echo "FAIL: STA did not produce reports (check $out/logs/pt.log)"
  elif [ "$viol" -gt 0 ]; then
    echo "FAIL: $viol setup violations — see $out/reports/timing_setup.rpt"
  else
    echo "PASS"
  fi
} | tee "$out/summary.txt"
grep -q "^PASS" "$out/summary.txt"
