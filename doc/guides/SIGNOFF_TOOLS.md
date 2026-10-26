# Sign-off tools on the training server

Every stage in the sign-off tracker, one command from your machine.
This guide walks through each one: what it does, what you need first,
how to run it, what the evidence looks like, and what to do when it fails.

## Prerequisites — once per member

| Step | Command | Notes |
|---|---|---|
| 1. WireGuard up | (team VPN) | the server is unreachable without it |
| 2. SSH key on server | `ssh-copy-id -i ~/.ssh/id_ed25519_<key>.pub doelab-red` | one-time; if it stops working later, a teammate overwrote the file — re-run (see troubleshooting) |
| 3. SSH alias | `Host doelab-red` block in `~/.ssh/config` (see below) | copy from the lead |
| 4. Server copy | `QSOC_SERVER=doelab-red make server-setup` | creates `~/qsoc.git` + `~/vlsi_deep_training` on the server, one-time |

SSH config block (paste into `~/.ssh/config`):
```
Host doelab-red red.doelab.site
    HostName red.doelab.site
    User qnsc_usr2
    IdentityFile ~/.ssh/id_ed25519_doelab
    IdentitiesOnly yes
```

Every command below runs from your machine, in the repository root.

## Stage: RTL integration — VCS compile

**What it checks:** the wrapper compiles under VCS (Synopsys's simulator).
CI already compiles with Verilator; this is the licensed cross-check.

**You need:** the wrapper RTL and `<block>.f` committed to your branch.

```bash
# compile the branch on the server (takes ~30 seconds)
QSOC_SERVER=doelab-red make vcs-branch BLOCK=pwm BRANCH=feat/pwm-wrapper

# post the result as a comment on your PR
QSOC_SERVER=doelab-red make vcs-post BLOCK=pwm PR=26
```

**Evidence on the PR:** one comment titled "**VCS compile on the training
server**" with PASS or FAIL, the commit hash, error count, and lint counts
(your files vs vendor). The comment is edited in place on re-runs.

**Reading the output:**
- `Error-: 0` → no syntax/elaboration errors; good
- `Error-: 3` → your RTL has VCS-specific issues; read the first errors in the log (path printed)
- `Lint-: N on our files` → VCS lint warnings on YOUR code; read and fix or waive
- `Lint-: M on vendor/` → vendor warnings; ignore (upstream, never edited)

**Verdi schematic (third check, manual):** the compile prints a path like
`cd /tmp/qsoc_vcs_qnsc_usr2/pwm/build/vcs/pwm && verdi -dbdir simv.daidir &`.
Open this in a desktop session on a compute node to see the schematic.
Check that every wrapper port reaches an IP port or a tie-off, as the MAS
interface table says.

## Stage: LINT — VC Static

**What it checks:** static lint with Synopsys VC StaticLint — a different
rule deck from Verilator's, catches different issues.

**You need:** the wrapper RTL and `<block>.f` (same as VCS).

```bash
QSOC_SERVER=doelab-red make vc-lint BLOCK=pwm BRANCH=feat/pwm-wrapper
QSOC_SERVER=doelab-red make vc-lint-post BLOCK=pwm PR=26
```

**Evidence on the PR:** one comment titled "**VC Static LINT on the training
server**" with PASS or FAIL. PASS means zero violations on your files
(vendor IPs are waived automatically from the filelist).

**When it fails:** the full report is in `build/vc/<block>/reports/lint_full.rpt`
on the server. Each violation names the rule, the file, and the line. Fix
your RTL, or add a waiver with a reason.

## Stage: CDC — VC Static CDC

**What it checks:** clock-domain crossings — every signal that crosses a
clock boundary must go through a synchroniser (qnsc_sync or a handshake).

**You need:** the block SDC file at `design/<block>/constraints/<block>.sdc`
(see the SDC template at `flow/sdc_template.sdc`) and optionally
`design/<block>/constraints/cdc_resets.tcl` (reset declarations).

```bash
QSOC_SERVER=doelab-red make vc-cdc BLOCK=pwm BRANCH=feat/pwm-wrapper
QSOC_SERVER=doelab-red make vc-cdc-post BLOCK=pwm PR=26
```

**If the SDC doesn't exist yet:** the command fails with a clear message
naming the exact path to write. Copy `flow/sdc_template.sdc`, fill in the
clock, delays, and CDC constraints for your block.

## Stage: RDC — VC Static RDC

**What it checks:** reset-domain crossings — flops reset by one domain,
sampled by another. The tool verifies the reset release is synchronised.

**You need:** same as CDC (SDC + reset declarations).

```bash
QSOC_SERVER=doelab-red make vc-rdc BLOCK=pwm BRANCH=feat/pwm-wrapper
QSOC_SERVER=doelab-red make vc-rdc-post BLOCK=pwm PR=26
```

## Stage: SYN — Design Compiler

**What it checks:** synthesis to the SMIC28 standard-cell library —
gate count, no latches, no multi-driven nets.

**You need:** the block SDC. The technology library and corner default to
SMIC28 ssg 0.72V -40°C (override with `QSOC_LIB_DIR=` and `QSOC_TARGET_LIB=`).

```bash
QSOC_SERVER=doelab-red make syn-dc BLOCK=pwm BRANCH=feat/pwm-wrapper
QSOC_SERVER=doelab-red make syn-dc-post BLOCK=pwm PR=26
```

**Evidence:** PASS with cell count and register count. Reports (area, timing,
power, QoR) are in `build/dc/<block>/reports/` on the server.

## Stage: STA/GCA — PrimeTime

**What it checks:** static timing analysis on the synthesised netlist —
setup and hold violations, unconstrained paths.

**You need:** the SYN output (netlist + mapped SDC). Run `make syn-dc` first
on the same branch — STA refuses to run without it.

```bash
QSOC_SERVER=doelab-red make sta-pt BLOCK=pwm BRANCH=feat/pwm-wrapper
QSOC_SERVER=doelab-red make sta-pt-post BLOCK=pwm PR=26
```

## Writing your block SDC

Copy the template:
```bash
cp flow/sdc_template.sdc design/<block>/constraints/<block>.sdc
```

The template covers:
1. **Clock** — `create_clock` 50ns on the block clock port
2. **I/O delays** — conservative 10ns both sides
3. **CDC constraints** — `set_false_path` for crossings through `qnsc_sync`
4. **Reset declaration** — for RDC

Adjust for your block: the clock port name comes from your MAS section 5,
the CDC constraints from your MAS crossing table.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Permission denied (publickey)` | SSH key was overwritten on the shared server | re-run `ssh-copy-id` (see prerequisites) |
| `vcs not found` / `vc_static_shell not found` | module not loaded in non-interactive shell | the harness loads it; if running manually: `module load synopsys/vcs/W-2024.09-SP1` |
| `FAIL: report is empty` | design didn't load — wrong filelist paths | check `<block>.f` has relative paths (not absolute) |
| `FAIL: synthesis needs SDC` | no SDC file yet | copy `flow/sdc_template.sdc`, fill in, commit |
| `FAIL: STA needs the DC netlist` | SYN hasn't been run | run `make syn-dc` first on the same branch |
| `the server linted abc1234 but PR is at def5678` | you pushed a new commit after the last tool run | re-run the tool + post on the new head |
| `no build/.../summary.txt` | the tool didn't run, or ran on a different path | re-run `make <tool>` first, then `make <tool>-post` |

## The full cycle for one block, start to finish

```
1. Write the wrapper (design/<block>/rtl/) and filelist (design/<block>/<block>.f)
2. Push the branch, open a PR → CI runs (lint, naming, connectivity, sim)
3. Compile on the server:      make vcs-branch BLOCK=x BRANCH=y
4. Post the VCS evidence:      make vcs-post BLOCK=x PR=n
5. LINT on the server:         make vc-lint BLOCK=x BRANCH=y
6. Post the LINT evidence:     make vc-lint-post BLOCK=x PR=n
7. (When SDC stage is due):    write constraints/<block>.sdc
8. SYN on the server:          make syn-dc BLOCK=x BRANCH=y
9. Post the SYN evidence:      make syn-dc-post BLOCK=x PR=n
10. CDC/RDC on the server:     make vc-cdc/vc-rdc BLOCK=x BRANCH=y
11. Post the evidence:         make vc-cdc-post/vc-rdc-post BLOCK=x PR=n
12. STA on the server:         make sta-pt BLOCK=x BRANCH=y
13. Post the evidence:         make sta-pt-post BLOCK=x PR=n
14. Open Verdi, look at the schematic, confirm MAS tables match
15. Request review — the PR now has every evidence the tracker asks
```
