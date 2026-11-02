# `rom` — boot ROM

**Owner:** @Nam-HaoNguyen   **Spec:** `QNSC_ROM_MAS.md` on the team SharePoint   **DV:** [`../../dv/rom`](../../dv/rom)

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
make gen-check                   # ROM_006, in CI: util/gen/rom/gen.sh regenerates the module from the hex
```

`util/gen/rom/rom_image.hex` is the built bootloader (`QNSC_BOOT_SPEC` V3.4,
xPack riscv-none-elf-gcc 15.2.0): 734 B image, 606 B of code after the vector
table. Rebuilding `design/rom/boot` gives the same hex byte for byte.
Verification (`dv/rom`) comes with the DV stage.

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

AXI ID: 3 bits (`PARA_ID_WD`), the width of an S_BUS master port. The CPU
issues a 1-bit ID, S_BUS is to take 1-bit slave-port IDs, and the crossbar adds
`$clog2(3 slave ports)` = 2 bits on its master ports (S_BUS owner, 2026-11-02;
`design/cpu/README.md` on the CPU branch). ISRAM, DSRAM and SYSDBG move to the
same width. The contract has no key for it yet.

## Compile with VCS

`vcs/` holds what anyone needs to compile this block with VCS on the training
server, by hand:

```
module load synopsys/vcs/W-2024.09-SP1
cd design/rom/vcs
./run_vcs                       # writes comp.log, simv, simv.daidir here (git-ignored)
verdi -dbdir simv.daidir &      # schematic, after module load synopsys/verdi/W-2024.09-SP1
```

`vcs/filelist.f` only includes `../rom.f`, so the files and their order stay
written once. `run_vcs` uses the flags of `flow/vcs/run_vcs`. Expected result:
`Error-: 0`.

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
