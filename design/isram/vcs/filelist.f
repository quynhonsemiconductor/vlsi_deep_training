# VCS filelist of the isram block. It only includes the block filelist, so the
# list of files and their order are written once, in design/isram/isram.f.
# -F: paths inside isram.f resolve from design/isram/, where isram.f lives.
# The shared cells (design/common) and the technology cells come from run_vcs,
# as in every flow of the repository.
-F ../isram.f
