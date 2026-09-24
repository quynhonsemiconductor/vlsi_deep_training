#!/usr/bin/env bash
# Report which tools this machine has for each stage, and how to install the
# missing ones. Installs nothing (make setup does that).
#
#   make doctor
#
# Exit status is 1 when a tool `make check` needs is missing.
set -uo pipefail

os=$(uname -s)
missing=0

# name | test command | needed for | required by make check | brew | apt
tools=(
  "python3|command -v python3|every check|yes|python|python3"
  "PyYAML|python3 -c 'import yaml'|contract, hardcode, docs|yes|pip: python3 -m pip install --user pyyaml|python3-yaml"
  "verilator|command -v verilator|lint, sim|yes|verilator|verilator"
  "emacs|command -v emacs|emacs wrappers|yes|emacs|emacs-nox"
  "pandoc|command -v pandoc|make docs|no|pandoc|pandoc"
  "rsvg-convert|command -v rsvg-convert|doc diagrams|no|librsvg|librsvg2-bin"
  "yosys|command -v yosys|make syn (later)|no|yosys|yosys"
  "sta|command -v sta|make gca (later)|no|build OpenSTA: github.com/parallaxsw/OpenSTA|build OpenSTA: github.com/parallaxsw/OpenSTA"
  "vcs|command -v vcs|make vcs (server only)|no|licensed, on the server|licensed, on the server"
)

printf '%-13s %-6s %-26s %s\n' "tool" "" "needed for" "install"
for t in "${tools[@]}"; do
  IFS='|' read -r name test need req brew apt <<< "$t"
  if eval "$test" >/dev/null 2>&1; then
    printf '%-13s %-6s %-26s\n' "$name" "ok" "$need"
  else
    [ "$os" = Darwin ] && hint="brew install $brew" || hint="sudo apt install $apt"
    case "$brew" in pip:*|build*|licensed*) [ "$os" = Darwin ] && hint="${brew#pip: }";; esac
    case "$apt" in build*|licensed*) [ "$os" != Darwin ] && hint="$apt";; esac
    if [ "$req" = yes ]; then mark="MISS"; missing=1; else mark="-"; fi
    printf '%-13s %-6s %-26s %s\n' "$name" "$mark" "$need" "$hint"
  fi
done

hooks=$(git config --get core.hooksPath || true)
if [ "$hooks" = ".githooks" ]; then
  printf '%-13s %-6s %-26s\n' "pre-push" "ok" "make check on git push"
else
  printf '%-13s %-6s %-26s %s\n' "pre-push" "-" "make check on git push" "make hooks"
fi

[ "$missing" = 0 ] && echo "ready for make check" || echo "MISS = needed by make check; run make setup, or the command shown"
exit $missing
