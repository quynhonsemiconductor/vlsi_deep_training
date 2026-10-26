# Server sign-off tools — one command per stage, one harness for all

Five Synopsys stages, each one command from a laptop, evidence on the PR:

| Stage | Run | Post | Tool |
|---|---|---|---|
| LINT | `make vc-lint BLOCK=x BRANCH=y` | `make vc-lint-post BLOCK=x PR=n` | VC Static |
| CDC | `make vc-cdc BLOCK=x BRANCH=y` | `make vc-cdc-post BLOCK=x PR=n` | VC Static + SDC |
| RDC | `make vc-rdc BLOCK=x BRANCH=y` | `make vc-rdc-post BLOCK=x PR=n` | VC Static + SDC |
| SYN | `make syn-dc BLOCK=x BRANCH=y` | `make syn-dc-post BLOCK=x PR=n` | Design Compiler |
| STA/GCA | `make sta-pt BLOCK=x BRANCH=y` | `make sta-pt-post BLOCK=x PR=n` | PrimeTime |

All need `QSOC_SERVER=<ssh alias>`. Each pushes the branch to the server
copy, checks out the flow branch there, runs the tool on a shade node through
Slurm with the right module loaded, and writes `summary.txt` + reports to
`build/<tool>/<block>/`. The post command puts the summary on the PR as one
comment per tool per PR, edited in place — the same contract as the VCS
compile summary, including the refuse-on-stale-commit guard.

## What the block owner must provide

| Stage | File the block needs | Convention |
|---|---|---|
| LINT | nothing beyond `<block>.f` | already in the repo |
| CDC, RDC | `design/<block>/constraints/<block>.sdc` + `constraints/cdc_resets.tcl` | CONTRIBUTING SDC stage |
| SYN | `design/<block>/constraints/<block>.sdc` | CONTRIBUTING SDC stage |
| STA | output of SYN (`make syn-dc` first) | — |

The harness fails with a clear message when the file is missing, naming the
exact path to write — it never silently skips a stage.

## What is generated, not hand-edited

For every tool the config tcl is generated from the block's own filelist:
the top module, the filelist, and for VC Static the vendor waive-by-IP list.
The technology library and corner default to the SMIC28 ssg 0.72V -40C
timing db (the assistant's DM_SYN/DM_STA configs) and can be overridden by
`QSOC_LIB_DIR` / `QSOC_TARGET_LIB`.

## Design: one command per stage, not one for all

The tracker closes stage by stage, and the stages unlock at different times
— CDC needs an SDC no block has yet, SYN needs the technology library. A
mega-command would either skip stages or wait for all of them. Instead,
every stage gets its own command with the same shape, all riding this one
harness: `flow/signoff.sh` (driver), `flow/signoff_run_branch.sh` (scratch
clone), `flow/vc/` + `flow/dc/` + `flow/pt/` (tool runners and tcl), and
`flow/post_signoff.sh` (evidence on the PR).

Adding a stage = adding its runner and tcl; the pipeline does not change.
