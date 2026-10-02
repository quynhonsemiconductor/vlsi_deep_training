# Contributing to QSOC

This is the order of work and the checks that gate it. It is a table of contents and
a sequence — the detail lives in the documents it links to, so that there is one
copy of each rule rather than two that drift apart.

## Read once, before your first block

| Document | What it gives you |
|---|---|
| [`doc/guides/GETTING_STARTED.md`](doc/guides/GETTING_STARTED.md) | Setup to merged PR, step by step, for any code |
| [`doc/guides/EMACS_AUTO.md`](doc/guides/EMACS_AUTO.md) | How to write a wrapper, or any module that instantiates others, with emacs AUTOs |
| [`design/README.md`](design/README.md) | The per-block convention: directory shape, why the filelist is not optional, the naming table, how to import the contract |
| [`doc/rules/`](doc/rules) | **Mandatory** Naming Rule (CI enforces it) and the EMACS quick guide |
| [`util/qsoc_contract.yml`](util/qsoc_contract.yml) | Every number shared between blocks, and where each came from |
| Your block's MAS under [`doc/specs/`](doc/specs) | What your block must do |
| [`doc/BLOCKS.md`](doc/BLOCKS.md) | Every block: directory, owner, specification. Status is in the teacher's assistant's tracker, not here |

## Writing a block — five steps

### 1. Take the numbers from the contract, do not invent them

```bash
grep -A4 "name: uart_0"        util/qsoc_contract.yml   # base address, bus port
grep -B1 -A4 "peripheral: uart_0" util/qsoc_contract.yml   # interrupt line
grep -A8 "clusters:"           util/qsoc_contract.yml   # which i_clk_<domain> you use
```

If the number you need is not there, **add it to the contract** — see
[Changing a shared number](#changing-a-shared-number). Never type it into the wrapper.
If it is not agreed yet (a DMA channel, a `CLK_EN` bit), add a `tbd:` entry that
names the owner in the same pull request. A number mentioned only in the PR text
is lost when the PR is merged.

### 2. Write the filelist `design/<block>/<block>.f`

Upstream IP is **listed**, never copied into `rtl/`. Order matters: packages and
`` `define `` files first, then leaf modules, then the IP's top, then your wrapper
last. Rationale in [`design/README.md`](design/README.md).

### 3. Write the wrapper `design/<block>/rtl/m_qnsc_wrap_<block>.sv`

Wrapper = core (the IP) + bridge (only if the IP speaks another protocol than the
chip bus). It is generated with emacs verilog-mode from a template:

```bash
make new-wrap BLOCK=<block> IP=vendor/<org>/<ip>/<ip_top>.sv   # once
# fill the AUTO_TEMPLATE in design/<block>/rtl/emacs/<wrapper>.src.sv
make wrap BLOCK=<block>                                       # after every edit
```

What a wrapper must do and the naming table are in
[`design/README.md`](design/README.md#the-wrapper-is-the-boundary); the emacs guide is
[`doc/guides/EMACS_AUTO.md`](doc/guides/EMACS_AUTO.md). A wrapper is IP: no `import`,
no parameter, the IP's configuration fixed at the instance, chip values on `i_cfg_*`
ports, and a number copied from the contract tagged `// contract: <key>`
([`design/README.md`, "Shared numbers"](design/README.md#shared-numbers-who-may-use-qnsc_pkg)).

### 4. Check locally before pushing

```bash
make doctor                 # once: which tools are missing (install list in README)
make hooks                  # once per clone: push runs make check; pull refreshes VS Code lint paths
make check                  # everything CI checks, before every push
make lint BLOCK=<block>     # one check, one block, while you work
make new-wrap BLOCK=<block> IP=<ip top .sv>   # scaffold an emacs wrapper, once
make wrap BLOCK=<block>     # regenerate an emacs wrapper after editing its .src.sv
make vcs BLOCK=<block>      # compile with VCS, on the server (CI uses Verilator)
make verdi BLOCK=<block>    # open that compile's schematic in Verdi, on the server
make help                   # the full list
```

Every CI step calls the same `make` target, so a green `make check` on your
machine is a green CI. How a wrapper is written with emacs is in
[`doc/guides/EMACS_AUTO.md`](doc/guides/EMACS_AUTO.md).

### 5. Open the pull request

- Title follows **Conventional Commits** — `feat(uart): add the APB wrapper`
- The block `README.md` names the **owner** and links the **spec**. Until the MAS is
  in `doc/specs/`, link wherever it lives. `_TBD_` is not accepted
- To catch up with `main`, **rebase** your branch (`git fetch && git rebase
  origin/main`); do not merge `main` into it. The repository accepts only squash
  and rebase merges ([`POLICY.md`](.github/POLICY.md)), so a merge commit on the
  branch breaks a rebase merge
- A **wrapper** PR carries a VCS compile summary of its **latest** commit
  (`Result: PASS`), posted as a PR comment: `make vcs-branch` on the server, then
  `make vcs-post` from your machine. Five steps in
  [`GETTING_STARTED.md`](doc/guides/GETTING_STARTED.md), "On the training server".
  CI cannot run VCS: it is licensed and exists only on the server
- A wrapper PR is checked three ways, each on its own:

  | Check | Who | Where it shows | Look for |
  |---|---|---|---|
  | **Connectivity** (Verilator, open source) | CI, automatic | a PR comment, updated on every push; `make connectivity BLOCK=<block>` locally | every row matches the MAS interface table (5) and tie-off table (10); nothing under "Allowed" that the MAS does not list |
  | **VCS compile** | owner, on the server | the `make vcs-post` comment | `Result: PASS`, and every `Lint-` on our files read |
  | **Verdi schematic** | owner, then reviewer, by hand | Remote Desktop on the server | the wrapper as drawn in the MAS block figure |

  The first two are evidence in the PR; the third is how the owner and the reviewer
  see the design. Connectivity is a cross-check from another tool, not a replacement:
  VCS and Verdi are the reference
- `main` is protected: no direct pushes, and a code-owner review is required
- These checks must pass (`make check` runs all but the last three locally):

| Check | Fails when |
|---|---|
| `PR title (conventional commits)` | the title is not a conventional commit |
| `Verilator lint` | your block does not lint through its filelist |
| `Filelist paths` | a path in a `.f` is absolute, or names a file that does not exist |
| `Generated wrappers` | `rtl/<wrapper>.sv` differs from what `make` generates from `rtl/emacs/<wrapper>.src.sv` |
| `Generated IP` | a file in `util/gen/<ip>/` differs from what its `gen.sh` produces with the pinned tools |
| `Connectivity` | a changed block's top leaves an instance input open, or drives a top output from nothing |
| `RTL naming rule` | an identifier breaks the naming rule — reported **inline on the diff** |
| `No hardcoded shared values` | a literal duplicates a contract constant, or lands inside a mapped region |
| `Inter-block contract` | `qnsc_pkg.sv` no longer matches the contract |
| `Vendor tree unmodified` | `vendor/` changed without `vendor/manifest.yml` |
| `Specifications build and check` | the specifications no longer build |
| `actions-security / Workflow lint (actionlint)` | a workflow file is malformed |
| `actions-security / Actions security (zizmor)` | a workflow has a security finding |

## What `vendor/` is

**Nobody writes code in `vendor/`.** Every file there is upstream code that
`util/vendor_ip.py` copies in at the commit pinned in `vendor/manifest.yml`, and
then patches with whatever sits in `vendor/patches/`. Our own RTL lives only in
`design/<block>/rtl/`.

```bash
python3 util/vendor_ip.py --list          # what is pinned, and where
python3 util/vendor_ip.py <name>          # (re)vendor one upstream at its pin
```

Commit the vendored files, the manifest and `vendor/vendor.lock.yml` together.

### Cases the basic rule does not spell out

| Case | Do this |
|---|---|
| The IP needs **another upstream** (a Bender dependency, a `common_cells` cell) | Vendor it as its **own manifest entry**, at the exact version the parent pins, with `files:` limited to what is compiled and `used_by:` naming the block. List only the compiled files in `<block>.f` |
| You vendor a repo only to **read** it, not compile it | Say "reference only, not compiled" in its manifest `notes:` and in the block README, and keep it out of `<block>.f` |
| The IP lacks a **feature** QSOC needs | Add it in the **wrapper** if it can be built from the IP's ports. Use a **patch** only when it needs the IP's internal state (the UART and I2C DMA request lines are the examples). Name it `vendor/patches/<vendor>_<repo>/NNNN-<what>.patch` and describe it in the manifest `notes:`, the block README and the MAS. Commit the patch and the patched vendor files in the same PR |
| The IP ships **templates and a generator**, not RTL (iDMA: Mako, SystemRDL, `gen_idma.py`) | Vendor the generator with the IP: add its files (for iDMA `util/gen_idma.py`, `util/mario/**`) to the entry's `files:`, same commit. In `util/gen/<ip>/` write `gen.sh` (the commands; reads `vendor/`, writes only into the directory it is given) and `requirements.txt` (the generator's Python tools, every version `==`, taken from the upstream lock file). Run `make gen IP=<ip>` and commit the generated files with the recipe; never edit them. List them in `<block>.f`. `make gen-check` (CI) regenerates and must match |
| Your wrapper **starts from an upstream file** (a sample wrapper) | Allowed as a starting point that you then own. Keep the upstream licence header, which the licence requires, and add one line `QNSC: derived from <path> @ <commit>`. State it in the README |

## Changing a shared number

A number in the contract is depended on by every block, so it does not move
quietly.

```bash
vim util/qsoc_contract.yml         # edit the source
python3 util/gen_qnsc_pkg.py       # regenerate the package
git add util/qsoc_contract.yml design/top/rtl/qnsc_pkg.sv   # commit BOTH
```

- **Adding** a number that was missing: include it with the block that needs it.
- **Changing** a number that exists: send it as its **own** pull request, so the
  effect on other blocks is visible instead of buried in a feature.
- A number used by **one** block only is not a shared number — it is the IP owner's
  configuration, written as a fixed value in the wrapper.

Numbers not yet agreed are listed under `tbd:` in the contract, each with the owner
who must supply it.

## Do not

| | Why |
|---|---|
| Edit anything under `vendor/` | It is vendored at a pinned commit so tape-out has a frozen, auditable source. Local fixes go in `vendor/patches/` with a reason. CI fails on it |
| Copy upstream IP into `design/<block>/rtl/` | `rtl/` is what makes "self-designed or IP?" answerable by reading one directory. List the IP in your filelist instead |
| Type an address, interrupt index or domain name into a wrapper | That is how ROM 8 KiB against 2 KiB, `APB_M11` against `APB_S11` and eleven interrupt sources against twelve all happened. A chip value reaches IP on an `i_cfg_*` port that `design/top` ties from `qnsc_pkg`; a structural number is tagged `// contract: <key>`. `No hardcoded shared values` fails the PR otherwise |
| Import a package or declare a parameter in a wrapper | The IP owner fixes the configuration; `design/top` only connects. verilog-mode does not resolve packages. `IP and integration module rules` fails the PR |
| Hand-edit `design/top/rtl/qnsc_pkg.sv` | It is generated. CI regenerates and compares |
| Fork the wrapper per instance for a value that differs | One wrapper; the value is an `i_cfg_*` port tied by `design/top`. A difference in structure is pending with Tâm (`design/README.md`, "Pending") |
| Instantiate a PDK cell (ICG, clock buffer, pad, SRAM macro) in block RTL | RTL instantiates `qnsc_clk_gate` and the other cells in `design/common/tech/`; `TECH` chooses which library implements them, so the same RTL simulates, runs on FPGA and synthesises for the ASIC. A new library cell is a file in `design/common/tech/<tech>/`, see its README |
| Rename a vendored module's port to satisfy the naming rule | The rule applies to our RTL. `naming_check.py` already skips identifiers after a dot, after `::`, and system functions such as `$clog2`, for exactly this reason |
| Rewrite correct RTL to dodge a checker false positive | Report the false positive and fix the checker in `flow/`. A `// naming-check: ignore -- <reason>` is the stop-gap, not a rewrite |

## Sign-off stages

Every IP moves through these stages; their status is kept in the teacher's
assistant's tracker, not in this repository. QSOC is a training project, so every
stage runs on **open-source tools**, in CI. The one licensed step is the VCS compile
of a wrapper on the training server (RTL integration). The stage names are the
tracker's; "VCS" is the simulation stage and runs on Verilator here. A stage that does not apply to a block
(for example CDC in a block with no clock) is waived in the block's README, with the
reason.

| Stage | Tool | Files, per block | Command | `done` when |
|---|---|---|---|---|
| **RTL integration** | Verilator (elaborate); VCS on the server | `design/<block>/rtl/`, `<block>.f` | `make lint BLOCK=<block>`; `make vcs BLOCK=<block>` | The wrapper follows [`design/README.md`](design/README.md), elaborates through `<block>.f` in both tools (VCS log in the PR), and is instantiated in `design/top` |
| **SIM** ("VCS") | Verilator `--binary --timing` | `dv/<block>/tb_<block>.sv`, `dv/<block>/tests/` | `make sim BLOCK=<block>` | Every test in the MAS verification section runs **self-checking** and ends in `PASS`; a failure calls `$fatal` |
| **LINT** | Verilator `--lint-only -Wall`, `naming_check.py`, `hardcode_check.py` | `design/<block>/waivers.vlt` | `make lint naming hardcode BLOCK=<block>` (CI) | All three are clean in CI. Every waiver line has a reason |
| **SDC** | OpenSTA syntax | `design/<block>/constraints/<block>.sdc` | read by the SYN and GCA stages | Every clock and every input/output is constrained. Clock names follow the table in [`flow/sta/README.md`](flow/sta/README.md). CDC paths carry the constraint their MAS states |
| **CDC** | Review against the MAS, plus lint | MAS crossing table | review in the pull request | Every crossing in the RTL is in the MAS crossing table, and every one goes through a shared cell in `design/common` or a handshake the MAS specifies. See [`flow/cdc/README.md`](flow/cdc/README.md) |
| **RDC** | Review against the MAS | MAS reset table | review in the pull request | Every reset domain is listed in the MAS, and no flop is reset by one domain and sampled by another without the MAS saying why it is safe. See [`flow/rdc/README.md`](flow/rdc/README.md) |
| **SYN** | Yosys, with the `yosys-slang` front end | none extra | `make syn BLOCK=<block>` | Synthesises with no latch and no multi-driven net. The cell count is stated in the pull request |
| **GCA** | OpenSTA `check_setup` | the block SDC | `make gca BLOCK=<block>` | `check_setup` reports no unconstrained clock, input, output or loop |

CDC and RDC have no mature open-source checker, so their evidence is the MAS table plus
the review. That is why every crossing must go through a **named shared cell**: it
makes a crossing findable with `grep` instead of by reading every line.

Mark a cell `done` only in the pull request that meets its definition, and link the
evidence (the CI run, the test log, the review comment) in that pull request.

## Ownership

Ownership is per directory in [`.github/CODEOWNERS`](.github/CODEOWNERS). `vendor/`,
`util/` and `design/top/` need a maintainer, because a change there reaches every
block. Repository policy, CI and the ruleset are described in
[`.github/POLICY.md`](.github/POLICY.md).

## Specifications

Markdown under [`doc/specs/`](doc/specs) is the source of truth; the `.docx` are built
from it with `make docs`. Rebuild before committing if you
changed the markdown — see [`doc/README.md`](doc/README.md).
