#!/usr/bin/env bash
# Generated IP: regenerate, or check that the committed files are a regeneration.
#
#   make gen IP=<ip>     regenerate util/gen/<ip>/ from its recipe
#   make gen-check       CI: every recipe reproduces its committed files exactly
#
# Some upstream IP ships templates and a generator instead of RTL (iDMA: Mako
# templates, SystemRDL and util/gen_idma.py). The generator is vendored with the IP,
# unmodified; its output is committed, so any clone compiles without the tools
# (the training server has no internet) and the RTL that goes into the chip is
# reviewable. A recipe directory util/gen/<ip>/ holds:
#
#   gen.sh             the commands, run as: bash gen.sh <out_dir>, from the repository
#                      root; reads only vendor/ and writes only into <out_dir>
#   requirements.txt   the generator's Python tools, every version pinned (==): the
#                      output depends on them as much as on the IP commit
#   everything else    the generated files, committed, never edited by hand
#
# The tools go in a virtual environment under build/gen/, made once per
# requirements file. Directories without gen.sh (rom, syscsr) have their own check.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"
own="gen.sh requirements.txt README.md"

venv_for() {                     # $1 = recipe dir; prints the venv's bin directory
  local req="$1/requirements.txt" key dir
  [ -f "$req" ] || { echo "$1: requirements.txt missing (pin the generator's tools)" >&2; return 1; }
  if grep -vE '^\s*(#|$)' "$req" | grep -vqE '==[0-9]'; then
    echo "$req: every line must pin a version with ==" >&2; return 1
  fi
  key=$(shasum "$req" 2>/dev/null | cut -c1-12 || sha1sum "$req" | cut -c1-12)
  dir="build/gen/venv-$(basename "$1")-$key"
  if [ ! -x "$dir/bin/python" ]; then
    python3 -m venv "$dir" >&2
    "$dir/bin/pip" install --quiet --disable-pip-version-check -r "$req" >&2
  fi
  echo "$root/$dir/bin"
}

generate() {                     # $1 = recipe dir, $2 = output dir
  local bin; bin=$(venv_for "$1")
  mkdir -p "$2"
  PATH="$bin:$PATH" bash "$1/gen.sh" "$2"
}

case "${1:-}" in
  gen)
    ip=${2:?usage: gen_ip.sh gen <ip>}; d="util/gen/$ip"
    [ -f "$d/gen.sh" ] || { echo "no $d/gen.sh"; exit 1; }
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    generate "$d" "$tmp"
    find "$d" -mindepth 1 -maxdepth 1 $(for f in $own; do printf -- '! -name %s ' "$f"; done) -exec rm -rf {} +
    cp -R "$tmp"/. "$d"/
    echo "regenerated $d; commit it with the recipe"
    ;;
  check)
    recipes=$(ls util/gen/*/gen.sh 2>/dev/null || true)
    [ -n "$recipes" ] || { echo "gen-check: no generator recipes"; exit 0; }
    fail=0
    for r in $recipes; do
      d=$(dirname "$r"); tmp=$(mktemp -d)
      if ! generate "$d" "$tmp" >/dev/null; then echo "FAIL $d: the recipe did not run"; fail=1; rm -rf "$tmp"; continue; fi
      if diff -r $(for f in $own; do printf -- '-x %s ' "$f"; done) "$tmp" "$d" > "$tmp.diff"; then
        echo "ok   $d"
      else
        echo "FAIL $d: committed files differ from a regeneration (make gen IP=$(basename "$d")):"
        sed -n 1,20p "$tmp.diff"; fail=1
      fi
      rm -rf "$tmp" "$tmp.diff"
    done
    exit $fail
    ;;
  *) echo "usage: gen_ip.sh gen <ip> | check"; exit 1;;
esac
