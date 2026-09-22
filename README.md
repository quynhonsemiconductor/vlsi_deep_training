# QSOC

A general-purpose 32-bit microcontroller, designed from the block level up as a
deep-training project. RV32IMC core, two bus levels, 98 KiB of on-chip memory and
twelve peripherals, targeting **SMIC 28 nm**.

There is no flash and no external memory interface, which shapes everything else:
the application is downloaded into RAM over the serial port after every reset, and
runs from there.

![QSOC block diagram](doc/img/fig_qsoc_full_mono.png)

Blocks with a **bold border** are designed here. The rest integrate upstream IP
through a wrapper.

## What it is

| | |
|---|---|
| **Core** | lowRISC **Ibex**, RV32IMC, two-stage pipeline, machine mode |
| **Clock** | one external 20 MHz input, no PLL — the PDK carries no analogue IP |
| **Memory** | 2 KiB ROM · 64 KiB instruction RAM · 32 KiB data RAM |
| **System bus** | AXI4 crossbar, fully connected, decode error on an unmapped address |
| **Peripheral bus** | APB4 router, 16 slaves |
| **Peripherals** | 2× UART · SPI host + device · I²C · 4× GPIO · 2× timer · PWM · watchdog · DMA |
| **Interrupts** | 27 sources → 11 fast lines + 1 NMI, through a combinational OR tree |
| **Debug** | JTAG, in-house: halt, resume, and memory access without the CPU |
| **Boot** | serial download into RAM, header + payload + CRC32, then jump |

Address map, interrupt assignment and clock domains live in one place —
[`util/qsoc_contract.yml`](util/qsoc_contract.yml) — and the package every block
imports is generated from it.

## Where the project is

Honest status, so nobody has to guess:

| | |
|---|---|
| Architecture and memory map | **agreed** — one contract file, checked by CI |
| Specifications | **5 of 16 blocks** written: RAM, SYSDBG, INTMAP, TIMER, PWM |
| RTL | **not started.** The scaffold, naming rules and CI are in place; wrappers are next |
| Verification | not started |
| Physical design | not started |

## Repository layout

| Path | Contents |
|------|----------|
| `design/` | RTL, one directory per block — see [`design/README.md`](design/README.md) |
| `doc/` | Specifications and the toolchain that builds them — see [`doc/README.md`](doc/README.md) |
| `vendor/` | Upstream IP, copied in at a pinned commit, never edited |
| `util/` | The inter-block contract, its generator, and the vendoring tool |
| `flow/` | Lint and the checks that gate a pull request |
| `dv/` · `pd/` · `fpga/` | Verification, physical design, FPGA bring-up |
| `.github/` | CI, ownership and repository policy — see [`.github/README.md`](.github/README.md) |

## Getting started

Needs Python 3 with PyYAML, `verilator` for lint, and `pandoc` to build the
specifications.

```bash
python3 flow/lint/naming_check.py      # naming rules
python3 flow/lint/hardcode_check.py    # no shared value typed by hand
bash    flow/lint/lint_all.sh          # Verilator, per block
python3 util/gen_qnsc_pkg.py --check   # the generated package matches the contract

cd doc && python3 build_docs.py        # build the specifications
python3 util/vendor_ip.py --list       # which upstream IP is pinned, and at what commit
```

## Contributing

**Start with [`CONTRIBUTING.md`](CONTRIBUTING.md)** — what to read first, the five
steps for writing a block, and the nine checks that gate a pull request.

`main` is protected: no direct pushes, and a code-owner review is required.
Ownership is per directory in [`.github/CODEOWNERS`](.github/CODEOWNERS).

Upstream IP is **vendored at a pinned commit rather than submoduled**, because
tape-out needs a frozen, auditable source: every upstream fact a specification
relies on is commit-specific. [`vendor/manifest.yml`](vendor/manifest.yml) records
each one, and CI refuses a change under `vendor/` that does not update it.

![Training flow](img/DeepTrainingFlow.jpg)
