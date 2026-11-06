# VCS filelist of the dsram block. It only includes the block filelist, so the
# list of files and their order are written once, in design/dsram/dsram.f.
# -F: paths inside dsram.f resolve from design/dsram/, where dsram.f lives.
# The shared cells (design/common) and the technology cells come from run_vcs,
# as in every flow of the repository.
-F ../dsram.f
