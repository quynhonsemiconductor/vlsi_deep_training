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

# One line per shared module: rtl/<module>.sv, relative to design/common. NOT listed in
# any block's filelist: every flow appends these as library files (flow/tech/libs.sh,
# "-v"), so a module is compiled where a block instantiates it, once, and two blocks
# that use it do not define it twice when the filelists are combined. The file is named
# after its module, so the editor finds it through design/common/rtl.
#
# rtl/<shared_module>.sv
