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
#   make help                  the full list
# =============================================================================
BLOCK ?=
TEST  ?=
BASE  ?= origin/main

SCOPE = $(if $(BLOCK),design/$(BLOCK))

.PHONY: help check filelists lint naming hardcode pkg pkg-check tables docs \
        vendor-guard new-wrap wrap wrap-check sim syn gca

help:
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
	@echo "make sim|syn|gca    later sign-off stages                 BLOCK= [TEST=]"

check: filelists lint naming hardcode pkg-check tables wrap-check vendor-guard

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

sim:
	bash flow/sim/run_sim.sh $(BLOCK) $(TEST)

syn:
	bash flow/syn/run_syn.sh $(BLOCK)

gca:
	bash flow/sta/run_gca.sh $(BLOCK)
