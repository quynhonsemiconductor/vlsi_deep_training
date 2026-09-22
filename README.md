# vlsi_deep_training

QSOC — a general-purpose RV32IMC microcontroller, designed as a deep-training
project. Target technology **SMIC 28 nm**, one 20 MHz clock, 98 KiB on-chip memory,
no flash and no external memory interface.

![Training Flow](img/DeepTrainingFlow.jpg)

## Repository layout

| Path | Contents |
|------|----------|
| `design/` | RTL, one directory per block. Each holds **only code written here**; upstream IP stays in `vendor/`. |
| `dv/` | Design verification |
| `pd/` | Physical design |
| `fpga/` | FPGA bring-up |
| `doc/` | Specifications (MAS) and the toolchain that builds them — see [`doc/README.md`](doc/README.md) |
| `util/` | Scripts and generator inputs, including `vendor_ip.py` |
| `vendor/` | Upstream IP, **vendored (copied in) rather than submoduled** — see below |
| `flow/` | Lint and synthesis scripts |
| `.github/` | CI, ownership and repository policy — see [`.github/README.md`](.github/README.md) |

## Blocks

Sixteen block directories under `design/`: `bus` `cpu` `dma` `gpio` `i2c` `intmap`
`iomux` `pwm` `ram` `scrc` `spi` `sysdbg` `timer` `top` `uart` `wdt`.

Five of them are documented so far — `ram` `sysdbg` `intmap` `timer` `pwm` — each with
a README stating what the block is, which upstream IP it borrows (if any), and a link
to its specification. The **wrapper is the boundary**: anything in
`design/<block>/rtl/` is ours, anything it instantiates from `vendor/` is not — so
reading one directory answers "self-designed or IP?".

## Specifications

Markdown under `doc/src/` is the **source of truth**; the `.docx` files are generated
and deliberately not committed.

```bash
cd doc && python3 build_docs.py    # needs pandoc
```

Five micro-architecture specifications are in the repository — `QNSC_RAM_MAS`,
`QNSC_SYSDBG_MAS`, `QNSC_Interrupt_Map_MAS`, `QNSC_TIMER_MAS`, `QNSC_PWM_MAS` — each
with a Vietnamese presentation script (`PRESENT_*_VI.md`) alongside it.

## Upstream IP

Third-party IP is **copied into `vendor/` at a pinned commit**, not submoduled. This
follows the methodology lowRISC documents for OpenTitan's `hw/vendor`, and the reason
is tape-out: every upstream fact a specification relies on is commit-specific, so the
source has to be frozen and auditable.

[`vendor/manifest.yml`](vendor/manifest.yml) records each upstream's URL, pinned
commit, licence, which files are taken and which block uses it.
[`vendor/vendor.lock.yml`](vendor/vendor.lock.yml) is the machine-written record of
what was actually imported.

```bash
python3 util/vendor_ip.py --list                 # what is pinned
python3 util/vendor_ip.py <name>                 # (re)import one upstream
```

**Two rules, enforced by CI:**

1. Do not edit files under `vendor/`. Local changes go in `vendor/patches/` with a
   reason, so the next upstream bump does not silently revert them.
2. Any change under `vendor/` must update `vendor/manifest.yml` in the same PR.

## Contributing

`main` is protected: no direct pushes, PRs require a passing CI run and code-owner
review. Ownership is per-directory in [`.github/CODEOWNERS`](.github/CODEOWNERS);
`vendor/` and the shared contract surfaces need a maintainer because a change there
affects every block.

PR titles follow Conventional Commits. CI runs Verilator lint per block, the two
`vendor/` guards, a specifications build, and GitHub Actions security checks.
