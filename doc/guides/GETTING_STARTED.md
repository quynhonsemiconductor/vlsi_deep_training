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
| [`doc/rules/`](../rules) | **Mandatory** Naming Rule V1.0, and Tâm's EMACS quick guide |
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

**Rules for all RTL** (the full table is in `design/README.md`, "Naming"):
- Ports start with `i_`, `o_` or `io_`: `i_clk_<domain>`, `i_rst_n_<domain>`,
  `i_bus_apb_*`, `i_bus_axi_<ch>_*`, `o_int_*`, `i_pad_*`/`o_pad_*`, `i_mem_*`, `i_dbg_*`.
- Internal signals: `r_*` for flops, `w_*` for combinational logic. Instances are
  `u_<function>[_<index>]`; parameters and constants are `P_*`, `C_*` and `S_*`.
- Shared numbers come from `import qnsc_pkg::*;` (`C_PWM_BASE`, `C_INT_LINE_PWM`, …).
  Never type them.
- A signal from another clock domain goes through `design/common/rtl/qnsc_sync.sv`, or
  through a handshake your MAS specifies.
- Module names: `m_qnsc_<function>` for in-house modules, `m_qnsc_wrap_<ip_module>`
  for wrappers, `qnsc_<function>` for shared cells.

**Filelist** `design/<block>/<block>.f`: list the package, then the shared cells, then
the IP files, then yours, with the top file last. Use paths relative to the filelist.
CI lints the block through this file only.

**Lint waiver:** a warning you accept on purpose goes in `design/<block>/waivers.vlt`,
one line per warning, each with its reason.

## 4. Check

```bash
make check                  # everything CI runs (the push hook runs it too)
make lint BLOCK=<block>     # one check, one block, while you work
make naming BLOCK=<block>
```

## 5. Pull request

1. Update `design/<block>/README.md` (Owner, Spec, IP, files, instances) and your row in
   [`doc/TRACKER.md`](../TRACKER.md) (`PR #n`).
2. Commit. For a generated wrapper, commit both the source and the generated file.
3. Title: a Conventional Commit, e.g. `feat(pwm): add the apb_adv_timer wrapper`.
4. To catch up with `main`: `git fetch && git rebase origin/main`. Never merge `main`
   into your branch.
5. `git push`. CI must pass all 11 checks.
6. Only the maintainers approve and merge: the teacher, Tâm, Nghia and Sinh. Tâm
   reviews wrappers.

## 6. When something fails

| Symptom | Fix |
|---|---|
| VS Code: `Import package not found: 'qnsc_pkg'` | Open the repository folder, then run `make ide` (or pull, and the hook does it) |
| `RTL naming rule` fails | Rename on our side: the right-hand side of the `AUTO_TEMPLATE`, or your own RTL. Never rename the IP |
| `No hardcoded shared values` fails | Use the `C_*` constant from `qnsc_pkg` it names |
| `Filelist paths` fails | A path in your `.f` is absolute, or names a missing file |
| `Generated wrappers` fails | You forgot `make wrap`, or edited a generated block by hand |
| `Verilator lint` fails | Read the `%Error` line; a missing file usually means a missing filelist entry |
| `make check` is fine but CI says the branch is out of date | `git fetch && git rebase origin/main`, then push |

## 7. Never

- Edit anything under `vendor/`. A change to an IP is a patch in `vendor/patches/`,
  agreed with a maintainer.
- Edit a generated file by hand: a generated wrapper block, or `design/top/rtl/qnsc_pkg.sv`.
- Type an address, an interrupt line or a domain name. Import it.
- Fork a wrapper per instance. Use one wrapper, and parameters for what differs.

Questions: the rules and wrappers → Tâm. The repository, CI and setup → Nghia.
