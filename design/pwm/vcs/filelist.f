# VCS filelist of the pwm block. It only includes the block filelist, so the
# list of files and their order are written once, in design/pwm/pwm.f.
# -F: paths inside pwm.f resolve from design/pwm/, where pwm.f lives.
# The shared cells (design/common) and the technology cells come from run_vcs,
# as in every flow of the repository.
-F ../pwm.f
