# `gpio` — general-purpose IO ports

**Owner:** @hieu-vubuiminh

**Spec:** [`QNSC_GPIO_MAS.md`](../../doc/specs/QNSC_GPIO_MAS.md)

**DV:** [`../../dv/gpio`](../../dv/gpio)

## What this block is

The GPIO block gives software control of eight bidirectional pad functions and
detects per-pin input edges. The QSOC top-level integration plan uses three
instances for GPIO0, GPIO1 and GPIO2: 24 GPIO functions in total. The current
repository contains and verifies the reusable eight-pin wrapper; top-level RTL
instantiation is not implemented yet.

## Uses (IP)

| From | Module | Recorded in |
|---|---|---|
| `pulp-platform/apb_gpio` @ `f82caeb7f7d89427f05e9af5ed31e0675efe0d83` | `apb_gpio` | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

The wrapper depends on the upstream APB interface, eight-pin configuration,
input synchroniser, output/direction controls, pad configuration output and one
interrupt output. The vendored RTL is listed in [`gpio.f`](./gpio.f); it is not
copied into `rtl/`.

## Wrapper policy

[`rtl/emacs/m_qnsc_wrap_gpio.src.sv`](./rtl/emacs/m_qnsc_wrap_gpio.src.sv)
is the source edited by the block owner. `make wrap BLOCK=gpio` uses Emacs
verilog-mode to generate [`rtl/m_qnsc_wrap_gpio.sv`](./rtl/m_qnsc_wrap_gpio.sv).
Do not edit the generated AUTO blocks by hand.

The PULP IP has no `PSTRB` or `PPROT` ports. Following the repository APB rule,
the wrapper does not add them:

- firmware uses aligned 32-bit writes; a sub-word write is not supported;
- access protection, if required, belongs in the interconnect;
- IP address aliases are accepted;
- the IP's `PREADY` and `PSLVERR` pass through unchanged;
- `dft_cg_enable_i` is tied low for QSOC v1.

The 32-bit `o_pad_gpio_cfg` bus is the flattened form of the IP's packed
`gpio_padcfg[7:0][3:0]`: bits `[4*n +: 4]` configure GPIO pin `n`.

## Instances

The top-level integration plan assigns three instances of this eight-pin
wrapper as follows:

| Instance | APB port | Base address |
|---|---|---:|
| GPIO0 | `APB_M3` | `0x8000_C000` |
| GPIO1 | `APB_M4` | `0x8001_0000` |
| GPIO2 | `APB_M5` | `0x8001_4000` |

Each instance emits one interrupt. The planned `INTMAP` integration ORs the
three sources onto fast interrupt line 9.

## Local checks

```bash
make wrap BLOCK=gpio
make lint BLOCK=gpio
make sim BLOCK=gpio
make naming BLOCK=gpio
make hardcode BLOCK=gpio
```
