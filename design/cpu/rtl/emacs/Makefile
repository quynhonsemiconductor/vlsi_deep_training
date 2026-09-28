.PHONY: all ibex cpu2axi cpu

all: ibex cpu2axi cpu

# Order matters: cpu.src.sv's AUTO_TEMPLATE instantiates m_qnsc_wrap_cpu_ibex
# and m_qnsc_wrap_cpu_cpu2axi by name, so both must already be regenerated
# (their ports read back in by Emacs via filelist_emacs_subsystem.f) before
# `cpu`. Both are named m_qnsc_wrap_cpu_<ip>, not m_qnsc_wrap_<ip>, per
# module_rules.py's WRAP-NAME check (design/README.md): a wrapper in
# design/cpu is m_qnsc_wrap_cpu or m_qnsc_wrap_cpu_<variant>, so the two
# sub-boundaries this block composes (around ibex_top, around the CPU2AXI
# bridge) take the block name as their prefix too.
#
# Each target's post-processing step is a REAL, repeatable tool limitation of
# verilog-mode's AUTOINST/AUTOWIRE against these specific vendor ports, not a
# one-off hand edit -- see the fixup scripts' own docstrings for what each
# step corrects and why, matching design/i2c/rtl/emacs/Makefile's own
# rtl_fix convention.
ibex:
	cp -rf m_qnsc_wrap_cpu_ibex.src.sv m_qnsc_wrap_cpu_ibex.sv
	emacs --batch m_qnsc_wrap_cpu_ibex.sv -f verilog-batch-auto
	python3 fixup_ibex_wrap.py m_qnsc_wrap_cpu_ibex.sv

cpu2axi:
	cp -rf m_qnsc_wrap_cpu_cpu2axi.src.sv m_qnsc_wrap_cpu_cpu2axi.sv
	emacs --batch m_qnsc_wrap_cpu_cpu2axi.sv -f verilog-batch-auto

cpu: ibex cpu2axi
	cp -rf m_qnsc_wrap_cpu.src.sv m_qnsc_wrap_cpu.sv
	emacs --batch m_qnsc_wrap_cpu.sv -f verilog-batch-auto
	python3 fixup_strip_bogus_struct_lines.py m_qnsc_wrap_cpu.sv
