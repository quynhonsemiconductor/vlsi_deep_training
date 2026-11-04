#!/bin/bash
# Open the last run_vcs.sh compile in Verdi (schematic: select the instance,
# right click > New Schematic). Needs a desktop session (Remote Desktop) on the
# compute node: srun --pty --x11 --nodelist=black -c 2 ./run_verdi.sh
cd "$(dirname "$0")"
if ! command -v verdi >/dev/null 2>&1; then
  source /usr/share/Modules/init/bash
  module use /tools/eda/modulefiles
  module load synopsys/vcs/W-2024.09-SP1 synopsys/verdi/W-2024.09-SP1
fi
verdi -dbdir simv.daidir &
