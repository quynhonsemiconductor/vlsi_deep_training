# =============================================================================
# Filelist for the uart block.
#
# This is the single place that says which files build this block, and in what
# order. CI lints the block through this file, so a file not listed here is not
# compiled and not checked.
#
# Rules:
#   - Upstream IP is LISTED here, never copied into rtl/. Paths are relative to
#     this file, so they start with ../../vendor/...
#   - Order matters. Packages and `define files first, then leaf modules, then
#     the modules that instantiate them, then our wrapper last.
#   - Anything under rtl/ is code written here. Anything under ../../vendor/ is
#     not ours -- see vendor/manifest.yml for its pinned commit and licence.
# =============================================================================

# ---- include directories ----------------------------------------------------
+incdir+../../vendor/pulp-platform/common_cells/include
+incdir+../../vendor/pulp-platform/apb/include
+incdir+../../vendor/pulp-platform/obi/include

# ---- shared contract --------------------------------------------------------
../top/rtl/qnsc_pkg.sv

# ---- upstream IP, in compile order -----------------------------------------
# pulp-platform/common_cells -- only the cells obi_uart and apb_to_obi use
../../vendor/pulp-platform/common_cells/src/cf_math_pkg.sv
../../vendor/pulp-platform/common_cells/src/sync.sv
../../vendor/pulp-platform/common_cells/src/delta_counter.sv
../../vendor/pulp-platform/common_cells/src/counter.sv
../../vendor/pulp-platform/common_cells/src/fifo_v3.sv
# pulp-platform/apb -- request/response structs
../../vendor/pulp-platform/apb/src/apb_pkg.sv
# pulp-platform/obi -- OBI package and the APB-to-OBI bridge
../../vendor/pulp-platform/obi/src/obi_pkg.sv
../../vendor/pulp-platform/obi/src/apb_to_obi.sv
# pulp-platform/obi_peripherals, with vendor/patches/pulp-platform_obi_peripherals/
# applied. Order is upstream's Bender.yml.
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart_pkg.sv
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart_baudgen.sv
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart_interrupts.sv
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart_modem.sv
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart_rx.sv
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart_tx.sv
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart_register.sv
../../vendor/pulp-platform/obi_peripherals/hw/obi_uart/obi_uart.sv

# ---- ours -------------------------------------------------------------------
rtl/m_qnsc_wrap_apb_uart.sv
