// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Shared bus/memory/timer/sim peripherals for Ibex example systems. Use with filelist/ibex_generic.f.
// Paths relative to design/ibex/.

+incdir+vendor/lowrisc_ip/ip/prim/rtl
+incdir+vendor/lowrisc_ip/dv/sv/dv_utils
+incdir+rtl

shared/rtl/bus.sv
shared/rtl/ram_1p.sv
shared/rtl/ram_2p.sv
shared/rtl/sim/simulator_ctrl.sv
shared/rtl/timer.sv
