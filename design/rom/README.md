# `rom` — boot ROM

**Owner:** @Nam-HaoNguyen   **Spec:** [`QNSC_ROM_MAS.md`](../../doc/specs/QNSC_ROM_MAS.md)   **DV:** [`../../dv/rom`](../../dv/rom)

## What this block is

2 KiB of read-only memory at `0x0000_0000` on `AXI_M0`, holding the serial
bootloader. With no flash, this is the only code present when the chip leaves
reset, so it is the first thing the core fetches and the only thing that can put
an application into RAM.

## Uses (IP)

| From | Module | Recorded in |
|------|--------|-------------|
| `nguyenquanicd/AXI4-SRAM-CONTROLLER` | same controller as ISRAM and DSRAM | [`vendor/manifest.yml`](../../vendor/manifest.yml) |

Read-only is achieved in the wrapper: the controller's write channel is tied idle
and a small responder answers every write with `SLVERR`. The contents are a
generated constant module, `m_qnsc_rom_image`, not a `$readmemh` array:

```bash
make -C design/rom/boot rtl      # boot.bin -> rom_image.hex -> util/gen/rom/{rom_image.hex, m_qnsc_rom_image.sv}
python3 util/gen_rom.py util/gen/rom/rom_image.hex util/gen/rom/m_qnsc_rom_image.sv --check   # ROM_006: image matches the hex
```

`util/gen/rom/rom_image.hex` is the built bootloader (xPack riscv-none-elf-gcc
15.2.0, 2026-09-29): 712 B image, 584 B of code after the vector table.
Verification (`dv/rom`) comes in a later pull request.

## The wrapper is the boundary

`rtl/` holds **only code written here**. Upstream IP is listed in
[`rom.f`](./rom.f), never copied into `rtl/`.

| File | Written by | What |
|---|---|---|
| `rtl/emacs/m_qnsc_wrap_rom.src.sv` | hand | Wrapper source: port groups, `AUTO_TEMPLATE`s, instances |
| `rtl/m_qnsc_wrap_rom.sv` | emacs, `make wrap BLOCK=rom` | The wrapper `rom.f` compiles; never edited by hand |
| `rtl/m_qnsc_rom_wr_resp.sv` | hand | Write-error responder (MAS 7.3), an FSM, so not generated |

Inside the wrapper: the controller (write channel tied idle, MAS Table 10-1),
the generated image on its memory port, and the responder on AW/W/B. The
responder's ports carry the wrapper's names, so its `AUTOINST` needs no
template.

## What the layout is forced by

The Ibex reset vector is `boot_addr_i + 0x80`, and the trap vector table sits at
`boot_addr_i + 0x00`. Since `mcause` 31 is the NMI, the table needs 32 entries —
128 bytes. So of 2 KiB:

| Offset | Size | Contents |
|---|---|---|
| `0x000` – `0x07F` | 128 B | trap vector table, forced by Ibex |
| `0x080` – `0x7FF` | **1920 B** | all the boot code there is |

1920 bytes is why the bootloader must use the **bitwise** CRC32: the table-driven
variant needs a 1 KiB table on top of the code, and does not fit.

## Instances

One, at `AXI_M0`. Separate from `design/isram/` and `design/dsram/`, which use the same
controller for ISRAM and DSRAM — the difference is this one is read-only and
carries build-time contents.
