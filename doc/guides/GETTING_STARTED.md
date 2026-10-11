# Getting started

From a fresh machine to a merged pull request, for any code in this repository:
a wrapper, an in-house block, the top level or a testbench. How to write a module
that instantiates others with emacs verilog-mode is in
[`EMACS_AUTO.md`](EMACS_AUTO.md).

## 0. Three words

| Word | What it is | Who writes it |
|---|---|---|
| **IP** | Code from outside (pulp, OpenTitan, the mentor), copied into `vendor/` at a pinned commit. **Never edited** | nobody here |
| **Wrapper** | The layer around one IP that makes it fit QSoC: rename ports to the Naming Rule, tie off what is unused, convert the protocol if needed (the *bridge*), add what the IP lacks. Wrapper = core (the IP) + bridge | the IP owner |
| **Top** | `design/top`: the whole chip. Instantiates every wrapper once per instance and wires them together | maintainers |

A block **designed in house** (SYSDBG, INTMAP) has no IP: its RTL is written here.

## 1. Set up (once)

1. Clone: `git clone git@github.com:quynhonsemiconductor/vlsi_deep_training.git`.
2. Install the tools in the table under "Getting started" in the root
   [`README.md`](../../README.md). macOS uses Homebrew; Ubuntu uses apt; Windows uses WSL2
   with Ubuntu.
3. `make doctor`. Install what it lists until it prints `ready for make check`.
4. `make hooks`. After this:
   - `git push` runs `make check` first. To skip it once, use `git push --no-verify`.
   - `git pull` and a branch switch refresh the editor's lint paths.
5. **VS Code** (recommended):
   - Open the **repository folder** itself (`code vlsi_deep_training`). If you open a
     parent folder, VS Code ignores `.vscode/settings.json` and shows false errors.
   - Accept the recommended extensions, Verible and Verilog-HDL.
   - Format with Shift+Alt+F; format-on-save is off for RTL. Never format a generated
     wrapper or anything under `vendor/`.

## 2. Read before your first block

| Document | Why |
|---|---|
| [`CONTRIBUTING.md`](../../CONTRIBUTING.md) | Order of work, the checks, what not to do |
| [`design/README.md`](../../design/README.md) | Block layout, naming table, the decisions the rule leaves open |
| [`doc/rules/`](../rules) | **Mandatory** Naming Rule V1.2, and Tâm's EMACS quick guide |
| Your block's MAS in [`doc/specs/`](../specs) | The ports QSoC needs (Interface), tie-offs, instances |
| [`util/qsoc_contract.yml`](../../util/qsoc_contract.yml) | Addresses, interrupt lines, clock domains. Never typed by hand |

Worked example: PR #26, the PWM wrapper.

## 3. Write the code

```bash
git switch main && git pull
git switch -c feat/<block>-<what>          # e.g. feat/pwm-wrapper
```

| Your code | How |
|---|---|
| A wrapper around an IP | `make new-wrap BLOCK=<block> IP=vendor/<org>/<ip>/<top>.sv`, then [`EMACS_AUTO.md`](EMACS_AUTO.md) |
| A module that instantiates others (block top, `design/top`, testbench top) | [`EMACS_AUTO.md`](EMACS_AUTO.md) |
| Logic (FSM, counter, register, OR tree) | Plain RTL by hand, rules below |
| A testbench (the SIM stage, its own pull request) | [`dv/README.md`](../../dv/README.md): `dv/<block>/tb_<block>.sv`, one self-checking test per MAS verification item. Example: `dv/pwm/` |

**Rules for all RTL** (the full table is in `design/README.md`, "Naming"):
- Ports start with `i_`, `o_` or `io_`, matching their direction: `i_clk_<domain>`,
  `i_rst_n_<domain>`, `i_bus_apb_*`, `i_bus_axi_<ch>_*`, `o_int_*`, `i_pad_*`/`o_pad_*`,
  `i_mem_*`, `i_dbg_*`. A module with several bus ports adds the port as the contract
  names it: `i_bus_axi_s_0_aw_addr`, `o_bus_apb_m_8_psel`.
- Internal signals: `r_*` for flops, `w_*` for combinational logic. Instances are
  `u_<function>[_<index>]`; parameters and constants are `P_*`, `C_*` and `S_*`.
- Types end in `_t`, and FSM states are enum members `S_*`:
  `typedef enum logic [1:0] {S_IDLE, S_BUSY} state_t;`. Packages are `qnsc_<function>_pkg`.
- One module (or package) per file, the file named after it. The top of your block is
  its wrapper `m_qnsc_wrap_<block>.sv`: no `_top` file.
- A clock gate, clock buffer or any other library cell: instantiate `qnsc_clk_gate`
  (and the others in `design/common/tech/`), never the PDK cell itself.
- Shared numbers live in `util/qsoc_contract.yml`. Integration modules (`top`, `bus`,
  `intmap`, `iomux`, `scrc`) take them from `qnsc_pkg`. **IP** (every wrapper, and
  `sysdbg`) does not: chip values arrive on `i_cfg_*` ports, and a number copied from
  the contract is tagged `// contract: <key>`. A wrapper has no `import` and no
  parameter (`design/README.md`, "Shared numbers").
- A signal from another clock domain goes through a synchroniser named `u_sync_*`, or
  through a handshake your MAS specifies, and is listed in the MAS crossing table
  ([`flow/cdc/README.md`](../../flow/cdc/README.md)).
- Module names: `m_qnsc_<function>` for in-house modules, `m_qnsc_wrap_<block>`
  for wrappers, `qnsc_<function>` for shared cells.

**Filelist** `design/<block>/<block>.f`: list the package, then the shared cells, then
the IP files, then yours, with the top file last. Use paths relative to the filelist.
CI lints the block through this file only.

**Lint waiver:** a warning you accept on purpose goes in `design/<block>/waivers.vlt`,
one line per warning, each with its reason.

## 4. Check

```bash
make check                  # every CI check that runs locally (the push hook runs it too)
make lint BLOCK=<block>     # one check, one block, while you work
make naming BLOCK=<block>
make connectivity BLOCK=<block>   # what the Connectivity comment will show
make sim BLOCK=<block>      # if dv/<block>/ has a testbench: CI runs it on every change
```

`make check` does not run Connectivity, Simulation or the full document build; CI
does. [`CONTRIBUTING.md`](../../CONTRIBUTING.md) marks which check runs where.

### On the training server: compile with VCS, look at the schematic

Everything above runs on your own machine. VCS and Verdi are licensed and run only
on a compute node of the training server, which cannot reach GitHub. So code goes
one way, **your machine → your repository copy on the server**, and you edit only on
your machine. Logging in, reaching a compute node, loading the tools and creating
that copy are in the **server guide**, shared privately by the lead (it names the
vendor's machines, so it is not in this public repository).

Your machine needs `bash`, `git`, `ssh` and `make`, plus `gh` for step 5 (or paste
the summary by hand). macOS and Linux have them; on **Windows, use WSL2** as for the
rest of this repository: PowerShell has no `bash`, and Windows' own OpenSSH cannot
share one login between commands (`ControlMaster`), so it asks for the password
every time. The server side is the same for everyone.

Once, from your machine, with your own server account: `QSOC_SERVER=<ssh alias>
make server-setup`. It creates `~/qsoc.git` and `~/vlsi_deep_training` in your server
home and the remote `server` here, with the same names for everyone.

For every wrapper PR, and again after every new commit on it:

| # | Where | Command |
|---|---|---|
| 1 | your machine | `git push server <branch>` |
| 2 | compute node, in your server copy | `git pull` (updates `flow/`, the scripts) |
| 3 | compute node | `make vcs-branch BLOCK=<block> BRANCH=<branch>` |
| 4 | compute node, in the desktop session | open the schematic with the `verdi` line step 3 prints |
| 5 | your machine | `QSOC_SERVER=<ssh alias> make vcs-post BLOCK=<block> PR=<number>` |

- Step 3 clones the branch to the node's local disk and compiles it there, so your
  copy stays on `main` and a network-home checkout never gets in the way.
  `make vcs BLOCK=<block>` compiles whatever your copy has checked out.
- It fails on any `Error-`, and on a tool option (such as `--top-module`) in the
  filelist. It counts `Lint-` on our files apart from `vendor/` (upstream, never
  edited): read ours, and fix or waive each.
- In the schematic every wrapper port reaches one IP port or a tie-off, as the MAS
  interface and tie-off tables say. The same connections, from Verilator, are in the
  **Connectivity** comment CI posts on the PR (`make connectivity BLOCK=<block>` on
  your machine, Verilator >= 5.022): compare the two, and the MAS.
- Step 5 refuses a summary of another commit than the PR head, and updates its own
  earlier comment instead of adding one.
- Nothing from the server is committed: `build/` is ignored, and `simv`, `csrc`, logs
  and anything under the vendor's tool or library paths stay there.

## 5. Pull request

1. Update `design/<block>/README.md` (Owner, Spec, IP, files, instances). Stage status is
   in the teacher's assistant's tracker; `doc/BLOCKS.md` changes only when a block, its
   owner or its specification changes.
2. Commit. For a generated wrapper, commit both the source and the generated file.
3. Title: a Conventional Commit, e.g. `feat(pwm): add the apb_adv_timer wrapper`.
4. To catch up with `main`: `git fetch && git rebase origin/main`. Never merge `main`
   into your branch.
5. `git push`. CI must pass every check.
6. Only the maintainers approve and merge: the teacher, Tâm, Nghia and Sinh. Tâm
   reviews wrappers.

## 6. When something fails

| Symptom | Fix |
|---|---|
| VS Code: `Import package not found: 'qnsc_pkg'` | Open the repository folder, then run `make ide` (or pull, and the hook does it) |
| `RTL naming rule` fails | Rename on our side: the right-hand side of the `AUTO_TEMPLATE`, or your own RTL. Never rename the IP. Each finding names its rule; the fix for each is in `design/README.md`, "Fixing a naming finding" |
| `No hardcoded shared values` fails | Integration module: use the `C_*` constant it names. IP: an `i_cfg_*` port, or tag the line `// contract: <key>` |
| `IP and integration module rules` fails | Remove the `import` or the parameter; see the message and `design/README.md`, "Shared numbers" |
| `Contract tags` fails | The number on the tagged line no longer equals the contract: fix the line, or the contract if the chip changed |
| `Filelist paths` fails | A path in your `.f` is absolute, or names a missing file |
| `Generated wrappers` fails | You forgot `make wrap`, or edited a generated block by hand |
| `Connectivity` fails | An instance input is left open, or a top output is driven by nothing: the comment's FAIL list names the pin. Tie it in the `AUTO_TEMPLATE`, as the MAS tie-off table says |
| `Generated IP` fails | A file in `util/gen/<ip>/` differs from what `make gen IP=<ip>` produces: regenerate, never edit by hand |
| `Simulation` fails | A test of your block, or of a block that compiles code you changed, fails: the comment names the `$fatal`. Reproduce with `make sim BLOCK=<block> WAVES=1` and open `build/sim/<block>/waves.vcd`, or download the `sim-waves` artifact |
| `Verilator lint` fails | Read the `%Error` line; a missing file usually means a missing filelist entry |
| `make check` is fine but CI says the branch is out of date | `git fetch && git rebase origin/main`, then push |

## 7. Never

- Edit anything under `vendor/`. A change to an IP is a patch in `vendor/patches/`,
  agreed with a maintainer.
- Edit a generated file by hand: a generated wrapper block, or `design/top/rtl/qnsc_pkg.sv`.
- Type an address, an interrupt line or a domain name. Integration modules take it
  from `qnsc_pkg`; IP takes it on an `i_cfg_*` port.
- Fork a wrapper per instance for a value that differs. Use one wrapper and an
  `i_cfg_*` port.

Questions: the rules and wrappers → Tâm. The repository, CI and setup → Nghia.
