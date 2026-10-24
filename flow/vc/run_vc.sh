#!/usr/bin/env bash
# Compile-free LINT with Synopsys VC Static, on a compute node. Run INSIDE the
# scratch clone that run_vc_branch.sh makes: the block's own filelist drives
# everything, the vendor list is waived by IP automatically (each /vendor/ file
# in the filelist names a module that is upstream and never edited).
#
#   bash flow/vc/run_vc.sh <block> <scripts-dir>
set -euo pipefail
block=${1:?block}
sdir=${2:?scripts dir, the working copy flow/vc}
flist="design/${block}/${block}.f"
[ -f "$flist" ] || { echo "no $flist"; exit 1; }
command -v vc_static_shell >/dev/null || { echo "load module synopsys/vc_static first"; exit 1; }

if grep -qE "(^|/)m_qnsc_wrap_${block}\.sv[[:space:]]*$" "$flist"; then
  top="m_qnsc_wrap_${block}"
else
  top=$(grep -oE 'rtl/[A-Za-z0-9_]+\.sv' "$flist" | tail -1 | xargs -n1 basename | sed 's/\.sv$//')
fi

# vendor modules in the filelist -> IP waiver list
ips=$(grep '/vendor/' "$flist" | grep -oE '[A-Za-z0-9_]+\.sv' | sed 's/\.sv$//' | sort -u | tr '\n' ' ')

out="build/vc/${block}"
mkdir -p "$out/logs" "$out/session" "$out/reports"

GW=""
for g in /tools/eda/synopsys/vc_static/*/auxx/monet/tcl/GuideWare/block/initial_rtl/lint/lint_functional_rtl.tcl; do
  [ -f "$g" ] && GW="$g" && break
done

cat > lint_config.tcl <<CFG
set TOP_MODULE              "$top"
set RTL_FILELIST            "$PWD/$flist"
set RTL_DEFINES             ""
set SESSION_DIR             "$out/session"
set SESSION_NAME            "${top}_lint"
set REPORT_DIR              "$out/reports"
set WAIVER_IP_LIST          [list ${ips}]
set LINT_RULESETUP          "$GW"
CFG

echo "== VC Static LINT: $block (top $top), vendor IPs waived: ${ips:-none}"
vc_static_shell -no_init -batch -mode64 -lic_wait 300 \
    -f "$sdir/check_lint.tcl" \
    -output_log_file "$out/logs/screen.log" || true

# Summary: ours vs vendor from the violation report paths, like the VCS lint split.
rpt="$out/reports/lint_full.rpt"
ours=0; vendor=0
if [ -f "$rpt" ]; then
  while IFS= read -r line; do
    case "$line" in
      *design/*) ours=$((ours+1));;
      *vendor/*|*/vendor/*) vendor=$((vendor+1));;
    esac
  done < <(grep -E '^\s*/|Source:' "$rpt" 2>/dev/null | grep -E 'design/|vendor/')
fi
{
  echo "VC_STATIC | block $block | top $top | commit $(git rev-parse --short HEAD 2>/dev/null || echo ?)"
  printf 'Compiled: %s\n' "$(date '+%Y-%m-%d %H:%M %Z')"
  echo "Lint-: $ours on our files, $vendor inside waived vendor IPs"
  if [ "$ours" -gt 0 ]; then
    echo "FAIL: $ours violations on our files (full report: $rpt)"
  else
    echo "PASS"
  fi
} | tee "$out/summary.txt"
[ "$ours" -eq 0 ]
