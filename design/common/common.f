# =============================================================================
# Filelist for shared RTL.
#
# Code here is instantiated by more than one block -- the APB-to-TL-UL adapter
# that both SPI and the watchdog need is the case this directory exists for.
# Writing it once keeps the two from diverging.
#
# Owned by the maintainers rather than a block owner, because a change here
# affects every block that instantiates it.
# =============================================================================

rtl/qnsc_sync.sv
