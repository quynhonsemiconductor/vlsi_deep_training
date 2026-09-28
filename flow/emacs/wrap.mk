# =============================================================================
# Shared rules for a wrapper generated with emacs verilog-mode.
#
# A block's design/<block>/rtl/emacs/Makefile is only:
#
#   DESIGN    = m_qnsc_wrap_<ip_module>
#   PARAM_FIX = <sed script>                                   # optional, rare
#   include ../../../../flow/emacs/wrap.mk
#
# `make` copies <DESIGN>.src.sv to <DESIGN>.sv, expands the AUTO comments
# (AUTOINST, AUTOINPUT, AUTOWIRE, AUTO_TEMPLATE) and copies the result to rtl/,
# which is the file <block>.f compiles. Instance parameters are already
# substituted by verilog-auto-inst-param-value t; PARAM_FIX is a sed script run
# after the expansion, only for what that cannot express.
#
# After the expansion, fix_pkg_ports.py removes the connections verilog-mode
# invents for an IP's package-typed ports and parameters (Ibex has both). It
# changes nothing for an IP without them.
#
# The target names are those of the I2C demo on share_review, so the format is
# the same for every block. Edit only the .src.sv; CI regenerates the wrapper
# and fails if the committed rtl/<DESIGN>.sv differs (flow/emacs/check_wrappers.sh).
# =============================================================================
SRC_FILE = $(DESIGN).src.sv
DST_FILE = $(DESIGN).sv
EMACS   ?= emacs
PYTHON  ?= python3
EMACS_FILELIST ?= filelist_emacs.f
WRAP_MK_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

.PHONY: all emacs_wrapper rtl_fix

all: emacs_wrapper rtl_fix

emacs_wrapper:
	cp -f $(SRC_FILE) $(DST_FILE)
	$(EMACS) --batch $(DST_FILE) --eval "(setq-default indent-tabs-mode nil)" -f verilog-batch-auto
	$(PYTHON) $(WRAP_MK_DIR)fix_pkg_ports.py $(DST_FILE) $(EMACS_FILELIST)

# -i.bak works with both GNU sed (Linux server) and BSD sed (macOS).
rtl_fix:
ifneq ($(strip $(PARAM_FIX)),)
	sed -i.bak '$(PARAM_FIX)' $(DST_FILE) && rm -f $(DST_FILE).bak
endif
	cp $(DST_FILE) ../
