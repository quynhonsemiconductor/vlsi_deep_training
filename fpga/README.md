# `fpga/` — FPGA prototype

Reserved for an FPGA build of QSOC, when the team decides to make one. Nothing here
is part of sign-off. The per-block and chip RTL in `design/` stay the single source; an
FPGA build only adds a board top, pin constraints and technology substitutions (for
example `prim_xilinx` instead of `prim_generic`), selected through filelists.
