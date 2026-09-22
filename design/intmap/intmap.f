# =============================================================================
# Filelist for the intmap block.
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
# +incdir+../../vendor/<upstream>/<path>

# ---- upstream IP, in compile order -----------------------------------------
# ../../vendor/<upstream>/rtl/<leaf>.sv
# ../../vendor/<upstream>/rtl/<top_of_ip>.sv

# ---- ours -------------------------------------------------------------------
# rtl/<wrapper>.sv
