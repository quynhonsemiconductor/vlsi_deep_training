# Contributing to QSOC

This is the order of work and the checks that gate it. It is a table of contents and
a sequence — the detail lives in the documents it links to, so that there is one
copy of each rule rather than two that drift apart.

## Read once, before your first block

| Document | What it gives you |
|---|---|
| [`design/README.md`](design/README.md) | The per-block convention: directory shape, why the filelist is not optional, the naming table, how to import the contract |
| `DM/RULES/FE/Release/QNSC_RTL_Design_Naming_Rule.pdf` (in `MCU_guide_ws`) | **Mandatory** naming rules. CI enforces them |
| [`util/qsoc_contract.yml`](util/qsoc_contract.yml) | Every number shared between blocks, and where each came from |
| Your block's MAS under [`doc/src/`](doc/src) | What your block must do |

## Writing a block — five steps

### 1. Take the numbers from the contract, do not invent them

```bash
grep -A4 "name: uart_0"        util/qsoc_contract.yml   # base address, bus port
grep -B1 -A4 "peripheral: uart_0" util/qsoc_contract.yml   # interrupt line
grep -A8 "clusters:"           util/qsoc_contract.yml   # which i_clk_<domain> you use
```

If the number you need is not there, **add it to the contract** — see
[Changing a shared number](#changing-a-shared-number). Never type it into the wrapper.

### 2. Write the filelist `design/<block>/<block>.f`

Upstream IP is **listed**, never copied into `rtl/`. Order matters: packages and
`` `define `` files first, then leaf modules, then the IP's top, then your wrapper
last. Rationale in [`design/README.md`](design/README.md).

### 3. Write the wrapper `design/<block>/rtl/m_qnsc_wrap_<ip>.sv`

```systemverilog
import qnsc_pkg::*;

module m_qnsc_wrap_uart (
  input  logic i_clk_peri,
  input  logic i_rst_n_peri,
  // ... APB per the naming rule: i_bus_apb_<signal>
  output logic o_int_uart_0
);
  apb_uart u_uart_0 (
    .clk_i (i_clk_peri),   // left side is the vendored module's port name
    ...
  );
endmodule
```

A wrapper does four things: **port-map** to the contract's names, **tie off** what
QSOC does not use, **adapt the protocol** if the IP speaks a different one, and
**add what the IP is missing** — the byte-enable path the RAM controller lacks is
the worked example.

### 4. Check locally before pushing

```bash
python3 flow/lint/naming_check.py design/<block>    # naming rule
bash    flow/lint/lint_all.sh                       # Verilator, through your filelist
```

Both run in CI. Running them first saves a round trip.

### 5. Open the pull request

- Title follows **Conventional Commits** — `feat(uart): add the APB wrapper`
- `main` is protected: no direct pushes, and a code-owner review is required
- Eight checks must pass:

| Check | Fails when |
|---|---|
| `PR title (conventional commits)` | the title is not a conventional commit |
| `Verilator lint` | your block does not lint through its filelist |
| `RTL naming rule` | an identifier breaks the naming rule — reported **inline on the diff** |
| `Inter-block contract` | `qnsc_pkg.sv` no longer matches the contract |
| `Vendor tree unmodified` | `vendor/` changed without `vendor/manifest.yml` |
| `Specifications build and check` | the specifications no longer build |
| `actions-security / Workflow lint (actionlint)` | a workflow file is malformed |
| `actions-security / Actions security (zizmor)` | a workflow has a security finding |

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
- A number used by **one** block only is not a shared number — make it a parameter
  in your wrapper.

Numbers not yet agreed are listed under `tbd:` in the contract, each with the owner
who must supply it.

## Instances are decided in `design/top`

You write **one** wrapper. `design/top` instantiates it as many times as the block
diagram shows: `uart` twice, `gpio` four times, `timer` twice with different
parameters, `ram` twice with different depths. What differs between instances is a
**parameter or a port** — never a forked file.

## Do not

| | Why |
|---|---|
| Edit anything under `vendor/` | It is vendored at a pinned commit so tape-out has a frozen, auditable source. Local fixes go in `vendor/patches/` with a reason. CI fails on it |
| Copy upstream IP into `design/<block>/rtl/` | `rtl/` is what makes "self-designed or IP?" answerable by reading one directory. List the IP in your filelist instead |
| Type an address, interrupt index or domain name into a wrapper | That is how ROM 8 KiB against 2 KiB, `APB_M11` against `APB_S11` and eleven interrupt sources against twelve all happened. Import it from `qnsc_pkg` |
| Hand-edit `design/top/rtl/qnsc_pkg.sv` | It is generated. CI regenerates and compares |
| Fork the wrapper per instance | One wrapper, parameters for the difference |
| Rename a vendored module's port to satisfy the naming rule | The rule applies to our RTL. `naming_check.py` already skips identifiers after a dot for exactly this reason |

## Ownership

Ownership is per directory in [`.github/CODEOWNERS`](.github/CODEOWNERS). `vendor/`,
`util/` and `design/top/` need a maintainer, because a change there reaches every
block. Repository policy, CI and the ruleset are described in
[`.github/README.md`](.github/README.md).

## Specifications

Markdown under [`doc/src/`](doc/src) is the source of truth; the `.docx` are built
from it with `cd doc && python3 build_docs.py`. Rebuild before committing if you
changed the markdown — see [`doc/README.md`](doc/README.md).
