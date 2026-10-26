#!/usr/bin/env bash
# VC Static (LINT / CDC / RDC), on a compute node, inside the scratch clone
# that run_vc_branch.sh makes. Config is generated from the block filelist.
#   bash run_vc.sh <block> <scripts-dir> <lint|cdc|rdc>
set -euo pipefail
block=${1:?block}
sdir=${2:?scripts dir}
mode=${3:?lint|cdc|rdc}
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

out="build/vc/${mode}/${block}"
mkdir -p "$out/logs" "$out/session" "$out/reports"

GW=""
for g in /tools/eda/synopsys/vc_static/*/auxx/monet/tcl/GuideWare/block/initial_rtl/lint/lint_functional_rtl.tcl; do
  [ -f "$g" ] && GW="$g" && break
done

# block SDC + CDC reset declarations (the documented convention)
sdc="design/${block}/constraints/${block}.sdc"
cdc_add="design/${block}/constraints/cdc_resets.tcl"
sdc_val=""; [ -f "$sdc" ] && sdc_val="$PWD/$sdc"
add_val=""; [ -f "$cdc_add" ] && add_val="$PWD/$cdc_add"

if [ "$mode" != "lint" ]; then
  if [ -z "$sdc_val" ]; then
    echo "FAIL: $mode needs design/${block}/constraints/${block}.sdc — none found."
    echo "      Write the SDC first (CONTRIBUTING sign-off SDC stage)."
    exit 2
  fi
fi

cfg="lint_config.tcl"
[ "$mode" = "cdc" ] && cfg="cdc_config.tcl"
[ "$mode" = "rdc" ] && cfg="rdc_config.tcl"

cat > "$cfg" <<CFG
set TOP_MODULE              "$top"
set RTL_FILELIST            "$PWD/$flist"
set RTL_DEFINES             ""
set SESSION_DIR             "$out/session"
set SESSION_NAME            "${top}_${mode}"
set REPORT_DIR              "$out/reports"
set WAIVER_IP_LIST          [list ${ips}]
set LINT_RULESETUP          "$GW"
set SDC_FILE                "$sdc_val"
set ADD_SDC_FILE            "$add_val"
CFG

tcl="check_lint.tcl"
[ "$mode" = "cdc" ] && tcl="check_cdc.tcl"
[ "$mode" = "rdc" ] && tcl="check_rdc.tcl"

echo "== VC Static ${mode^^}: $block (top $top), vendor IPs waived: ${ips:-none}"
vc_static_shell -no_init -batch -mode64 -lic_wait 300 \
    -f "$sdir/$tcl" \
    -output_log_file "$out/logs/screen.log" || true

rpt="$out/reports/${mode}_full.rpt"
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
  echo "VC_STATIC ${mode^^} | block $block | top $top | commit $(git rev-parse --short HEAD 2>/dev/null || echo ?)"
  echo "Compiled: $(date '+%Y-%m-%d %H:%M %Z')"
  echo "${mode^}-: $ours on our files, $vendor inside waived vendor IPs"
  if [ -f "$rpt" ] && grep -qE 'TopLevelModule: *$' "$rpt"; then
    echo "FAIL: report is empty -- design did not load (check $out/logs/screen.log)"
    exit 1
  fi
  if [ "$ours" -gt 0 ]; then
    echo "FAIL: $ours violations on our files (full report: $rpt)"
  else
    echo "PASS"
  fi
} | tee "$out/summary.txt"
[ "$ours" -eq 0 ]
