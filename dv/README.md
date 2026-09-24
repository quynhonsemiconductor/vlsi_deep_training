# `dv/` — design verification (SIM stage)

One directory per block, mirroring `design/`. The simulator is **Verilator**
(`--binary --timing`); the tracker column is still called "VCS" after the teacher's
tracker.

## Structure

```
dv/<block>/
  tb_<block>.sv      top-level testbench, module tb_<block>
  tb.f               extra testbench files, models and packages (optional)
  tests/             one file or task per test, named after the MAS check it covers
  README.md          which MAS verification items are covered, and which are not yet
```

The design under test is built from `design/<block>/<block>.f`, the same filelist the
LINT stage uses. Never keep a second list of design files here.

## Rules

1. **Self-checking.** A test compares against an expected value and ends with a line
   containing `PASS`. On a mismatch it calls `$fatal` with what was expected and what
   was seen. A test that only produces a waveform does not count.
2. **One test per MAS verification item.** Name the test after it (for example
   `t07_cdc_tck_stop` for SYSDBG check 7), so the MAS and the regression can be
   compared line by line.
3. **Models, not vendor edits.** A model the IP lacks (for example an SRAM macro with
   byte enables) goes in `dv/<block>/`, never in `vendor/` or `design/`.
4. **Items that need simulation to confirm** a MAS claim are marked
   "confirm in simulation" in the MAS; each one needs a test before the SIM cell is `done`.

## Running

```bash
bash flow/sim/run_sim.sh <block>            # the default test
bash flow/sim/run_sim.sh <block> <test>     # passes +test=<test> to the testbench
```

Output goes to `build/sim/`, which is not committed.
