# `vcs/` — VCS compile of the wdt block

The run and config files to compile `m_qnsc_wrap_wdt` with Synopsys VCS, so
anyone can re-check the release or investigate.

| File | What |
|---|---|
| `run_vcs.sh` | Compiles `../wdt.f` (top `m_qnsc_wrap_wdt`), prints `Error-`/`Lint-` counts and `Result: PASS` or `FAIL`. Same flags as `flow/vcs/run_vcs` |
| `run_verdi.sh` | Opens the compile (KDB) in Verdi for the schematic |

```bash
# training server, on a compute node (at most 2 CPUs per job)
srun --nodelist=black -c 2 ./run_vcs.sh
# in the Remote Desktop session
srun --pty --x11 --nodelist=black -c 2 ./run_verdi.sh
```

The scripts load `synopsys/vcs/W-2024.09-SP1` and `synopsys/verdi/W-2024.09-SP1`
with `module` when `vcs` is not on `PATH`. Files must have LF line endings: a
CRLF checkout breaks the multi-line macros of `prim_assert.sv`.
