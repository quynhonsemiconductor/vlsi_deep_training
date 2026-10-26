# VC Static — LINT (CDC, RDC later) on the training server

One command from your machine, per block:

```bash
QSOC_SERVER=doelab-red make vc-lint BLOCK=pwm BRANCH=feat/pwm-wrapper
QSOC_SERVER=doelab-red make vc-post BLOCK=pwm PR=26
```

- `lint.sh` pushes the branch to your server copy, checks out the flow branch
  (`VC_FLOW_BRANCH`, default `main`) there, and runs the LINT on a shade node
  through Slurm (`module load synopsys/vc_static`).
- `run_vc_branch.sh` clones the block branch into scratch (design untouched),
  `run_vc.sh` generates `lint_config.tcl` from the block's own filelist: the
  top, the filelist, and the vendor waiver-by-IP list (every `/vendor/` file in
  the filelist is an upstream module never edited here — same split as the VCS
  lint count).
- The summary (`summary.txt`) counts violations on our files apart from the
  waived vendor IPs; `PASS` means zero on ours. The full and waived reports
  come back to `build/vc/<block>/` in your server copy.
- `post_vc.sh` posts the summary as one comment on the PR, edited in place —
  the same contract as the VCS compile summary. It refuses a summary whose
  commit is not the PR head.

CDC and RDC use the same shell with their own configs (`goal cdc`, `rdc`
rule decks) — the harness is the pattern, only the config and the parser grow.

## Design: one command per stage, one harness for all

The sign-off tracker closes stage by stage, and stages unlock at different
times — CDC needs an SDC no block has yet, SYN needs the technology library.
So there is no single "run everything" command, and that is deliberate: a
mega-command would either skip stages (many commands wearing a coat) or wait
for all of them (today's LINT could not have run).

Instead, every stage gets its own command with the same shape —
`make <tool> BLOCK=x BRANCH=y` then `make <tool>-post BLOCK=x PR=n` — all
riding one harness:

| Tracker stage | Command | Status |
|---|---|---|
| RTL integration | `make vcs-branch` + `make vcs-post` | ready (`flow/vcs`) |
| SIM | CI (`make sim`) | ready |
| LINT | `make vc-lint` + `make vc-post` | this PR |
| CDC / RDC | `make cdc-vc` / `make rdc-vc` | same shell, other rule decks — next |
| SYN | `make syn-dc` | needs the DC module + tech libs |
| STA/GCA | `make sta-pt` | needs block SDCs |

Adding a stage means adding its rule deck and parser to this directory; the
pipeline (push, Slurm, generated config, summary, PR comment) does not change.
