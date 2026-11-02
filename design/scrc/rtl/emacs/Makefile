DESIGN    = m_qnsc_scrc
# o_rst_n_por is a port (AUTOOUTPUTEVERY) that RRC and the sysdbg CTRL also read.
# verilog-mode expands AUTOWIRE before AUTOOUTPUTEVERY and declares it a second
# time as a wire; the sed removes that one line.
PARAM_FIX = /^logic[[:space:]]*o_rst_n_por;/d

include ../../../../flow/emacs/wrap.mk
