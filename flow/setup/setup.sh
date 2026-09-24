#!/usr/bin/env bash
# Install what `make check` needs, then turn on the pre-push hook.
#
#   make setup
#
# macOS uses Homebrew; Ubuntu or Debian uses apt (needs sudo). On a machine
# without either -- the training server, usually -- run `make doctor` and ask
# the administrator for what it lists. Tools for later stages (yosys, OpenSTA,
# VCS) are not installed here; make doctor shows how.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

if [ "$(uname -s)" = Darwin ] && have brew; then
  pkgs=()
  have verilator    || pkgs+=(verilator)
  have emacs        || pkgs+=(emacs)
  have pandoc       || pkgs+=(pandoc)
  have rsvg-convert || pkgs+=(librsvg)
  [ ${#pkgs[@]} -eq 0 ] || brew install "${pkgs[@]}"
  python3 -c 'import yaml' 2>/dev/null || python3 -m pip install --user pyyaml
elif have apt-get; then
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends \
    python3 python3-yaml verilator emacs-nox pandoc librsvg2-bin make git
else
  echo "no Homebrew or apt here: run make doctor and install what it lists"
  exit 1
fi

git config core.hooksPath .githooks
echo
bash flow/setup/doctor.sh
