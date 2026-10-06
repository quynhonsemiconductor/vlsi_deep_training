.PHONY: all cpu

all: cpu

# One wrapper, directly instantiating ibex_top and m_qnsc_cpu2axi connected
# to each other (leader review 2026-09-28: connect the core to the bridge
# first, then wrap the pair in one m_qnsc_wrap_cpu -- see
# doc/specs/QNSC_CPU_DECISIONS.md). Emacs needs both filelist_emacs.f (for
# ibex_top's own port list) and filelist_emacs_bridge.f (for m_qnsc_cpu2axi's)
# to resolve both instantiations' AUTOINST in one pass -- see the .src.sv's
# own Local Variables footer.
#
# The post-processing step is a REAL, repeatable tool limitation of
# verilog-mode's AUTOINST against ibex_top's specific ports, not a one-off
# hand edit -- see fixup_ibex_wrap.py's own docstring for what it corrects
# and why, matching design/i2c/rtl/emacs/Makefile's own rtl_fix convention.
cpu:
	cp -rf m_qnsc_wrap_cpu.src.sv m_qnsc_wrap_cpu.sv
	emacs --batch m_qnsc_wrap_cpu.sv -f verilog-batch-auto
	python3 fixup_ibex_wrap.py m_qnsc_wrap_cpu.sv
