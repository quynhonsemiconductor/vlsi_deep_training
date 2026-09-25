# =============================================================================
# Shared rules for a wrapper generated with emacs verilog-mode.
#
# A block's design/<block>/rtl/emacs/Makefile is only:
#
#   DESIGN    = m_qnsc_wrap_<ip_module>
#   PARAM_FIX = <sed script>                                   # optional, rare
#   include ../../../../flow/emacs/wrap.mk
#
# `make` expands the AUTO comments (AUTOINST, AUTOINPUT, AUTOWIRE,
# AUTO_TEMPLATE) of rtl/<DESIGN>.sv, the file <block>.f compiles -- in place,
# or from rtl/emacs/<DESIGN>.src.sv in the I2C demo format (see below).
# Instance parameters are substituted by verilog-auto-inst-param-value t;
# PARAM_FIX is a sed script run after the expansion, only for what that cannot
# express. CI regenerates every wrapper and fails if the committed
# rtl/<DESIGN>.sv differs (flow/emacs/check_wrappers.sh).
# =============================================================================
SRC_FILE = $(DESIGN).src.sv
DST_FILE = $(DESIGN).sv
EMACS   ?= emacs
AUTO     = --eval "(setq-default indent-tabs-mode nil)" -f verilog-batch-auto

.PHONY: all emacs_wrapper rtl_fix in_place

# Two formats. With rtl/emacs/<DESIGN>.src.sv (the I2C demo): copy, expand the
# copy, copy it to rtl/. Without it: rtl/<DESIGN>.sv is the only file and is
# expanded in place, which is how verilog-batch-auto is meant to be used
# ("load the file, update the automatics, and re-save the file", Veripool FAQ).
ifneq ($(wildcard $(SRC_FILE)),)
all: emacs_wrapper rtl_fix
else
all: in_place
endif

in_place:
	cd .. && $(EMACS) --batch $(DST_FILE) $(AUTO)
ifneq ($(strip $(PARAM_FIX)),)
	sed -i.bak '$(PARAM_FIX)' ../$(DST_FILE) && rm -f ../$(DST_FILE).bak
endif

emacs_wrapper:
	cp -f $(SRC_FILE) $(DST_FILE)
	$(EMACS) --batch $(DST_FILE) $(AUTO)

# -i.bak works with both GNU sed (Linux server) and BSD sed (macOS).
rtl_fix:
ifneq ($(strip $(PARAM_FIX)),)
	sed -i.bak '$(PARAM_FIX)' $(DST_FILE) && rm -f $(DST_FILE).bak
endif
	cp $(DST_FILE) ../
