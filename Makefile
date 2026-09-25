# =============================================================================
# One entry point for every check CI runs.
#
# Each target calls the same script the CI job calls, so a green `make check` on
# your machine is a green CI. The logic stays in flow/, util/ and doc/; this file
# only names it.
#
#   make check                 everything below except docs, before every push
#   make lint BLOCK=pwm        one block; omit BLOCK for all
#   make wrap BLOCK=pwm        regenerate an emacs wrapper
#   make doctor                which tools this machine has, and how to get the rest
#   make hooks                 once per clone: make check before push, editor paths after pull
#   make help                  the full list
# =============================================================================
BLOCK ?=
TEST  ?=
BASE  ?= origin/main

SCOPE = $(if $(BLOCK),design/$(BLOCK))

.PHONY: help check filelists lint naming hardcode pkg pkg-check tables docs \
        vendor-guard new-wrap wrap wrap-check vcs sim syn gca hooks doctor ide

help:
	@echo "make doctor         which tools are here, and how to install the rest"
	@echo "make ide            editor lint search paths (.vscode/verilator.f)"
	@echo "make hooks          once per clone: run make check before every push"
	@echo "make check          all CI checks: filelists lint naming hardcode pkg-check tables wrap-check vendor-guard"
	@echo "make filelists      paths in every .f are relative and exist"
	@echo "make lint           Verilator lint through <block>.f      [BLOCK=]"
	@echo "make naming         QNSC_RTL_Design_Naming_Rule           [BLOCK=]"
	@echo "make hardcode       no shared value typed by hand         [BLOCK=]"
	@echo "make pkg            regenerate qnsc_pkg.sv from the contract"
	@echo "make pkg-check      qnsc_pkg.sv matches the contract"
	@echo "make tables         specification tables match the contract"
	@echo "make docs           build every .docx from doc/src"
	@echo "make vendor-guard   vendor/ unedited since BASE             [BASE=origin/main]"
	@echo "make new-wrap       scaffold rtl/emacs for a new wrapper   BLOCK= IP=<ip top .sv>"
	@echo "make wrap           regenerate one emacs wrapper           BLOCK="
	@echo "make wrap-check     every emacs wrapper matches its .src.sv"
	@echo "make vcs            compile with VCS, on the server        BLOCK="
	@echo "make sim|syn|gca    later sign-off stages                 BLOCK= [TEST=]"

ide:
	@python3 flow/ide/gen_verilator_f.py > /dev/null

doctor:
	bash flow/setup/doctor.sh

hooks:
	git config core.hooksPath .githooks
	@echo "hooks on: git push runs make check (skip once with --no-verify);"
	@echo "          git pull and branch switches refresh the editor lint paths"

check: ide filelists lint naming hardcode pkg-check tables wrap-check vendor-guard

filelists:
	python3 flow/lint/filelist_check.py

lint:
	bash flow/lint/lint_all.sh $(BLOCK)

naming:
	python3 flow/lint/naming_check.py $(SCOPE)

hardcode:
	python3 flow/lint/hardcode_check.py $(SCOPE)

pkg:
	python3 util/gen_qnsc_pkg.py

pkg-check:
	python3 util/gen_qnsc_pkg.py --check

tables:
	python3 doc/tools/gen_doc_tables.py --check

docs:
	cd doc && python3 build_docs.py

vendor-guard:
	bash flow/lint/vendor_guard.sh $(BASE)

new-wrap:
	@test -n "$(BLOCK)" -a -n "$(IP)" || { echo "usage: make new-wrap BLOCK=<block> IP=<path to ip top .sv>"; exit 1; }
	bash flow/emacs/new_wrapper.sh $(BLOCK) $(IP)

wrap:
	@test -n "$(BLOCK)" || { echo "usage: make wrap BLOCK=<block>"; exit 1; }
	$(MAKE) -C design/$(BLOCK)/rtl/emacs

wrap-check:
	bash flow/emacs/check_wrappers.sh

vcs:
	@test -n "$(BLOCK)" || { echo "usage: make vcs BLOCK=<block>"; exit 1; }
	bash flow/vcs/run_vcs $(BLOCK)

sim:
	bash flow/sim/run_sim.sh $(BLOCK) $(TEST)

syn:
	bash flow/syn/run_syn.sh $(BLOCK)

gca:
	bash flow/sta/run_gca.sh $(BLOCK)
