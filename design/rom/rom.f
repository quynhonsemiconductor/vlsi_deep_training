# =============================================================================
# Filelist for the rom block.
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
#
# The ROM reuses the same controller as ISRAM and DSRAM
# (nguyenquanicd/AXI4-SRAM-CONTROLLER); what differs is that the write channel is
# tied to its idle state, so the array is read-only, and the array is initialised
# with the bootloader at build time.
# =============================================================================

# ---- include directories ----------------------------------------------------
# +incdir+../top/rtl

# ---- upstream IP, in compile order -----------------------------------------
# ../../vendor/nguyenquanicd/AXI4-SRAM-CONTROLLER/rtl/m_vlsi_fifo.sv
# ../../vendor/nguyenquanicd/AXI4-SRAM-CONTROLLER/rtl/m_vlsi_axi4_sram.sv

# ---- ours -------------------------------------------------------------------
# rtl/m_qnsc_wrap_rom.sv
