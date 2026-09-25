# QSOC sign-off tracker

One row per IP, one column per sign-off stage. It mirrors the tracker kept by the
teacher's assistant, and adds the repository directory so a status can be checked
against the code. What each column means, which open-source tool runs it and when
a cell may be marked `done` is in
[`CONTRIBUTING.md`, "Sign-off stages"](../CONTRIBUTING.md#sign-off-stages).

**Cell values:** `-` not started · `WIP` in progress · `PR #n` under review · `done`
meets the definition of done · `waived` not applicable, reason in the Comment column.

**Who updates it:** the IP owner, in the same pull request that completes the stage.
The overall lead checks it against the repository before each review.

| No | IP | Repo directory | Owner | RTL integration | SIM (VCS) | LINT | SDC | CDC | RDC | SYN | GCA | Comment |
|---:|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | CPU | `design/cpu` | Truong Sinh | PR #1 | - | - | - | - | - | - | - | |
| 2 | SYSDBG | `design/sysdbg` | Trong Nghia | - | - | - | - | - | - | - | - | MAS V3.0 |
| 3 | ROM | `design/rom` | Hao Nam | - | - | - | - | - | - | - | - | |
| 4 | SRAM | `design/ram` | Trong Nghia | - | - | - | - | - | - | - | - | MAS V2.2 |
| 5 | S_BUS | `design/bus` | Truong Sinh | - | - | - | - | - | - | - | - | |
| 6 | P_BUS | `design/bus` | Truong Sinh | - | - | - | - | - | - | - | - | |
| 7 | DMA | `design/dma` | Bao Vinh | - | - | - | - | - | - | - | - | |
| 8 | PWM | `design/pwm` | Trong Nghia | - | - | - | - | - | - | - | - | MAS V2.1 |
| 9 | TIMER | `design/timer` | Trong Nghia | - | - | - | - | - | - | - | - | MAS V2.1 |
| 10 | I2C | `design/i2c` | Bao Vinh | PR #11 | - | PR #11 | - | - | - | - | - | |
| 11 | SPI | `design/spi` | Bui Hieu | - | - | - | - | - | - | - | - | |
| 12 | UART | `design/uart` | Bao Vinh | PR #12 | - | PR #12 | - | - | - | - | - | |
| 13 | GPIO | `design/gpio` | Bui Hieu | - | - | - | - | - | - | - | - | MAS V1.2, 3 banks |
| 14 | WDT | `design/wdt` | Bui Hieu | - | - | - | - | - | - | - | - | |
| 15 | SYSCSR | `design/scrc` | Hao Nam | - | - | - | - | - | - | - | - | Register file inside SCRC |
| 16 | SCRC | `design/scrc` | Hao Nam | - | - | - | - | - | - | - | - | |
| 17 | INTMAP | `design/intmap` | Trong Nghia | - | - | - | - | - | - | - | - | MAS V2.2 |
| 18 | IO MUX | `design/iomux` | Bui Hieu | - | - | - | - | - | - | - | - | Not on the assistant's tracker yet |
| 19 | TOP | `design/top` | Trong Nghia (lead) | - | - | - | - | - | - | - | - | `qnsc_pkg.sv` only so far |

## Names that differ between the tracker and the repository

| Tracker | Repository |
|---|---|
| SRAM | `design/ram` (ISRAM and DSRAM are two instances) |
| S_BUS, P_BUS | `design/bus` |
| SYSCSR | the status register file inside `design/scrc` |
| VCS | the simulation column; QSOC runs it with Verilator, see `CONTRIBUTING.md` |
