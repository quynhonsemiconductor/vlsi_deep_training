# =============================================================================
# Shared rules for a wrapper generated with emacs verilog-mode.
#
# A block's design/<block>/rtl/emacs/Makefile is only:
#
#   DESIGN    = m_qnsc_wrap_<block>
#   PARAM_FIX = s,\[APB_ADDR_WIDTH-1,[C_APB_PADDR_WIDTH-1,g     # optional
#   include ../../../../flow/emacs/wrap.mk
#
# `make` copies <DESIGN>.src.sv to <DESIGN>.sv, expands the AUTO comments
# (AUTOINST, AUTOINPUT, AUTOWIRE, AUTO_TEMPLATE) and copies the result to rtl/,
# which is the file <block>.f compiles. PARAM_FIX is a sed script applied after
# the expansion, for an IP parameter the wrapper replaces with a qnsc_pkg name.
#
# The target names are those of the I2C demo on share_review, so the format is
# the same for every block. Edit only the .src.sv; CI regenerates the wrapper
# and fails if the committed rtl/<DESIGN>.sv differs (flow/emacs/check_wrappers.sh).
# =============================================================================
SRC_FILE = $(DESIGN).src.sv
DST_FILE = $(DESIGN).sv
EMACS   ?= emacs

.PHONY: all emacs_wrapper rtl_fix

all: emacs_wrapper rtl_fix

emacs_wrapper:
	cp -f $(SRC_FILE) $(DST_FILE)
	$(EMACS) --batch $(DST_FILE) -f verilog-batch-auto

# -i.bak works with both GNU sed (Linux server) and BSD sed (macOS).
rtl_fix:
ifneq ($(strip $(PARAM_FIX)),)
	sed -i.bak '$(PARAM_FIX)' $(DST_FILE) && rm -f $(DST_FILE).bak
endif
	cp $(DST_FILE) ../
