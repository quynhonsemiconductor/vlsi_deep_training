# `dv/syscsr` — testbench of `m_qnsc_wrap_syscsr`

`make sim BLOCK=syscsr`. One simulation runs every test in `tests/`, in order;
each prints `SYSCSR_NNN ok: ...` and the run ends with `PASS`.

| MAS item | Test | Covered |
|---|---|---|
| `SYSCSR_001` | `tests/syscsr_001.svh` | yes |
| `SYSCSR_002`--`SYSCSR_010` | -- | not yet |
| `SYSCSR_011` | `tests/syscsr_011.svh` | yes |
| `SYSCSR_012` | `tests/syscsr_012.svh` | yes |
| `SYSCSR_013` | `tests/syscsr_013.svh` | yes |
