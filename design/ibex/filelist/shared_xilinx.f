// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Shared peripherals plus Xilinx 7-series clock generator. Use with filelist/ibex_xilinx.f.
// prim_xilinx provides no dual-port RAM, so ram_2p.sv uses the generic prim_ram_2p.
// Paths relative to design/ibex/.

+incdir+vendor/lowrisc_ip/ip/prim/rtl
+incdir+vendor/lowrisc_ip/dv/sv/dv_utils
+incdir+rtl

// --- packages ---
vendor/lowrisc_ip/ip/prim_generic/rtl/prim_ram_2p_pkg.sv

// --- generic dual-port RAM (no Xilinx variant upstream) ---
vendor/lowrisc_ip/ip/prim_generic/rtl/prim_ram_2p.sv

// --- shared peripherals ---
shared/rtl/bus.sv
shared/rtl/ram_1p.sv
shared/rtl/ram_2p.sv
shared/rtl/sim/simulator_ctrl.sv
shared/rtl/timer.sv
shared/rtl/fpga/xilinx/clkgen_xil7series.sv
