# `dv/sbus` — S_BUS testbench

Testbench `tb_sbus` for `m_qnsc_wrap_sbus` (design/sbus): three masters (SYSDBG `s_0`, CPU `s_1`,
DMA `s_2`), three AXI slave models (ROM, ISRAM, DSRAM) and one APB slave model. Self-checking;
the run ends with `PASS: tb_sbus, <n> checks`.

```bash
make sim BLOCK=sbus                  # Verilator, as CI
```

On the training server the same files were also run with VCS (4-state, so an X shows up as a
failed check): `vcs -sverilog -F design/sbus/sbus.f -F dv/sbus/tb.f dv/sbus/tb_sbus.sv -top tb_sbus`.

## How the DUT is wired

The instance is written by emacs `AUTOINST` with a template, the way TOP will wire it: each flat
port `i_bus_axi_s_<n>_<channel>_<signal>` reaches the field of the same name in `tb_s_req[n]` /
`tb_s_resp[n]` (and `m` for the master ports). 270 AXI pins and 9 APB pins, 281 in all. After
changing the DUT's ports or the template:

```bash
emacs --batch dv/sbus/tb_sbus.sv -f verilog-batch-auto
```

## Tie-offs

ROM, ISRAM and DSRAM wrappers have no `b_user` and `r_user`, so TOP ties the six inputs
`i_bus_axi_m_{0,1,2}_{b,r}_user` to 0. `tb_axi_mem` ties them to 0 itself. The outputs no slave
takes (`aw_size`, `aw_lock`, `aw_cache`, `aw_prot`, `aw_qos`, `aw_region`, `aw_atop`, `aw_user`,
`w_user` and the `ar_*` ones) are left open.

## Tests

The S_BUS MAS lives on the team SharePoint and is not in this repository, so the tests carry their
own IDs. Map them to the MAS items when it is at hand.

| Test | What it checks |
|---|---|
| `SBUS_001` | each end of every window reaches only its slave, read and write; data, OKAY, ID kept |
| `SBUS_002` | an unmapped address (holes, APB slots 14 and 15, past the window) gets DECERR, no slave sees it |
| `SBUS_003` | the DMA cannot reach ROM or ISRAM (DECERR); it reaches DSRAM and APB; SYSDBG and CPU reach ROM and ISRAM |
| `SBUS_004` | master-port ID is `{slave port, id}` (3 bit); each master gets its own 1-bit ID back on B and R |
| `SBUS_005` | bursts of 4, 8 and 16 beats through fast and slow slaves; RLAST; partial strobes |
| `SBUS_006` | AXI2APB: paddr (18-bit offset), pwdata, pstrb, pwrite; PSLVERR becomes SLVERR; bursts (see below); APB protocol |
| `SBUS_007` | three masters at once to one slave, to three slaves, two on the APB window |

## Worth knowing

A burst of more than one beat into the APB window is refused with SLVERR when `AxCACHE` is
non-modifiable (Device, `4'b0000`): `axi_to_axi_lite` carries `axi_burst_splitter`, which does not
split a Device burst (AXI spec A3.4.1). The same burst with `CACHE_MODIFIABLE` is split into one APB
access per beat. The CPU's data port and the DMA both drive `AxCACHE` 0, so a DMA burst to a
peripheral register would get SLVERR. `SBUS_006` pins both behaviours.

## Not covered yet

- SYSDBG has no RTL yet, so port `s_0` is driven by the testbench only.
- No test of `UniqueIds` / `AxiIdUsedSlvPorts` (open items in `qnsc_sbus_pkg`).
- No random traffic and no ID-reorder test.
