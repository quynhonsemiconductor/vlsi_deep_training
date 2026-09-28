# QSOC blocks

Where each IP lives in the repository, who owns it and where its specification is.
The names in the first column are those of the teacher's assistant's tracker.

**Status is not kept here.** The sign-off status of every IP (RTL integration, SIM,
LINT, SDC, CDC, RDC, SYN, GCA) is in the teacher's assistant's tracker; what each
stage requires is in [`CONTRIBUTING.md`, "Sign-off stages"](../CONTRIBUTING.md#sign-off-stages),
and work in progress is visible as an open pull request.

| No | IP | Repo directory | Owner | Specification |
|---:|---|---|---|---|
| 1 | CPU | `design/cpu` | Truong Sinh | -- |
| 2 | SYSDBG | `design/sysdbg` | Trong Nghia | [`QNSC_SYSDBG_MAS`](specs/QNSC_SYSDBG_MAS.md) |
| 3 | ROM | `design/rom` | Hao Nam | [`QNSC_ROM_MAS`](specs/QNSC_ROM_MAS.md), [`QNSC_BOOT_SPEC`](specs/QNSC_BOOT_SPEC.md) |
| 4 | SRAM | `design/isram`, `design/dsram` | Trong Nghia | [`QNSC_RAM_MAS`](specs/QNSC_RAM_MAS.md) |
| 5 | S_BUS | `design/bus` | Truong Sinh | -- |
| 6 | P_BUS | `design/bus` | Truong Sinh | -- |
| 7 | DMA | `design/dma` | Bao Vinh | [`QNSC_DMA_MAS`](specs/QNSC_DMA_MAS.md) |
| 8 | PWM | `design/pwm` | Trong Nghia | [`QNSC_PWM_MAS`](specs/QNSC_PWM_MAS.md) |
| 9 | TIMER | `design/timer` | Trong Nghia | [`QNSC_TIMER_MAS`](specs/QNSC_TIMER_MAS.md) |
| 10 | I2C | `design/i2c` | Bao Vinh | [`QNSC_I2C_MAS`](specs/QNSC_I2C_MAS.md) |
| 11 | SPI | `design/spi` | Bui Hieu | -- |
| 12 | UART | `design/uart` | Bao Vinh | [`QNSC_UART_MAS`](specs/QNSC_UART_MAS.md) |
| 13 | GPIO | `design/gpio` | Bui Hieu | -- |
| 14 | WDT | `design/wdt` | Bui Hieu | [`QNSC_WDT_MAS`](specs/QNSC_WDT_MAS.md) |
| 15 | SYSCSR | `design/scrc` | Hao Nam | [`QNSC_SYSCSR_MAS`](specs/QNSC_SYSCSR_MAS.md) |
| 16 | SCRC | `design/scrc` | Hao Nam | [`QNSC_SCRC_MAS`](specs/QNSC_SCRC_MAS.md) |
| 17 | INTMAP | `design/intmap` | Trong Nghia | [`QNSC_Interrupt_Map_MAS`](specs/QNSC_Interrupt_Map_MAS.md) |
| 18 | IO MUX | `design/iomux` | Bui Hieu | -- |
| 19 | TOP | `design/top` | Trong Nghia (lead) | -- |

A `--` is a block whose specification is not in the repository yet.

## Names that differ between the tracker and the repository

| Tracker | Repository |
|---|---|
| SRAM | `design/isram` and `design/dsram`: one IP, two configurations, two wrappers |
| S_BUS, P_BUS | `design/bus` |
| SYSCSR | the status registers in `design/scrc`, a separate APB slave on `APB_M1` |
| IO MUX | not on the assistant's tracker yet |
| VCS | the simulation stage; QSOC runs it with Verilator, see `CONTRIBUTING.md` |
