# =============================================================================
# Filelist for the i2c block.
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
# i2c_master_defines.sv is pulled in by `include from the three sources below, so
# it is on the include path and deliberately NOT listed as a source.
+incdir+../../vendor/pulp-platform/apb_i2c

# ---- shared contract --------------------------------------------------------
../top/rtl/qnsc_pkg.sv

# ---- upstream IP, in compile order -----------------------------------------
# pulp-platform/apb_i2c, with vendor/patches/pulp-platform_apb_i2c/ applied
../../vendor/pulp-platform/apb_i2c/i2c_master_bit_ctrl.sv
../../vendor/pulp-platform/apb_i2c/i2c_master_byte_ctrl.sv
../../vendor/pulp-platform/apb_i2c/apb_i2c.sv

# ---- ours -------------------------------------------------------------------
rtl/m_qnsc_wrap_apb_i2c.sv
