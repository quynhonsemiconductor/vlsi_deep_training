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
4. **One line per passing test**, starting with its MAS ID: `PWM_004 ok: <what was
   checked>`. CI counts and lists these lines; the run still ends with `PASS`.
5. **Items that need simulation to confirm** a MAS claim are marked
   "confirm in simulation" in the MAS; each one needs a test before the SIM cell is `done`.

## Running

```bash
make sim BLOCK=<block>                   # the default test
make sim BLOCK=<block> TEST=<test>       # passes +test=<test> to the testbench
make sim BLOCK=<block> TEST=<test> WAVES=1   # also writes build/sim/<block>_<test>/waves.vcd
```

Output goes to `build/sim/`, which is not committed. The technology cells
(`design/common/tech/$TECH`) are added as for every other flow.

## In CI

The job **Simulation** runs `make sim` for every block a pull request changes that has
a `tb_<block>.sv`, and for every such block when code they all compile changes
(`design/common/`, `flow/sim/`, `flow/tech/`, `vendor/`). It posts one comment with a
PASS/FAIL row per block, and keeps the waveform of a failing block as the artifact
`sim-waves` for seven days.

A block with **no testbench yet is skipped, not failed**: the testbench belongs to the
SIM stage, not to the pull request that writes the RTL. Once a block has tests, every
pull request that touches it must keep them passing.

`make check` does not run simulation, so the pre-push hook stays fast; run
`make sim BLOCK=<block>` before pushing a change to a block that has tests.

## Waveforms

A waveform is a by-product of a test, for understanding and debugging; it is not a
check (rule 1). With `WAVES=1` the testbench gets `+waves=<file>` and dumps when it
is present:

```systemverilog
initial begin
  string w;
  if ($value$plusargs("waves=%s", w)) begin
    $dumpfile(w);
    $dumpvars(0, tb_<block>);
  end
end
```

Open the `.vcd` with Surfer (the VS Code extension, or the web version) or GTKWave.
A waveform that goes into a document is converted to WaveDrom and committed as
`design/<block>/doc/*.json` and `.svg`, from the simulation, never drawn by hand.
