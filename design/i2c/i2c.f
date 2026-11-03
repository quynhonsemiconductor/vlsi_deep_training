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
+incdir+../../vendor/pulp-platform/apb_i2c

# ---- upstream IP, in compile order -----------------------------------------
../../vendor/pulp-platform/apb_i2c/i2c_master_defines.sv
../../vendor/pulp-platform/apb_i2c/i2c_master_bit_ctrl.sv
../../vendor/pulp-platform/apb_i2c/i2c_master_byte_ctrl.sv
../../vendor/pulp-platform/apb_i2c/apb_i2c.sv

# ---- ours -------------------------------------------------------------------
rtl/m_qnsc_wrap_i2c.sv
