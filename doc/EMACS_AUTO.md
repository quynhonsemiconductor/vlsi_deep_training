# Writing a module that instantiates others: emacs verilog-mode AUTOs

The mentors ask the team to use emacs `verilog-mode`, as industry does. You do **not**
type a port list or an instance's pin connections. You write short rules, and emacs
reads the instantiated module's ports and fills in the rest.

**Use it for** any module whose main job is to instantiate other modules and connect
them:

- a wrapper around an IP;
- the top of an in-house block (SYSDBG: TAP + CDC + AXI manager);
- `design/top`;
- a testbench top.

**Do not use it for** plain logic (an FSM, a counter, a register file, the INTMAP OR
tree). Write that by hand.

References:
- [`doc/rules/EMACS_quick_guide.pdf`](rules/EMACS_quick_guide.pdf): the template and
  every template function.
- [Veripool verilog-mode help](https://veripool.org/verilog-mode/help/).
- Worked example: PR #26 (PWM).

## 1. The files

| File | You edit it? | What it is |
|---|---|---|
| `rtl/emacs/<wrapper>.src.sv` | ✍️ yes | The source: port groups, added logic, `AUTO_TEMPLATE`s, instances |
| `rtl/emacs/filelist_emacs.f` | ✍️ yes | The files of the modules you instantiate, so emacs can read their ports |
| `rtl/emacs/Makefile` | rarely | `DESIGN = <wrapper>`, then `include` of `flow/emacs/wrap.mk` |
| `rtl/emacs/<wrapper>.sv` | 🤖 no | Intermediate copy expanded by emacs |
| `rtl/<wrapper>.sv` | 🤖 no | The expanded wrapper that `<block>.f` compiles |

`make new-wrap BLOCK=<block> IP=<ip top .sv>` creates the first three from
`flow/emacs/template.src.sv.in`. `make wrap BLOCK=<block>` writes the last two.

> **Being piloted in PR #26: one file.** verilog-mode is designed to expand the AUTOs
> **in place** ("load the file, update the automatics, and re-save the file",
> Veripool FAQ). In that format there is no `.src.sv` and no intermediate copy: you
> edit `rtl/<wrapper>.sv` outside the generated blocks, and `make wrap` rewrites
> those blocks in the same file. `wrap.mk` supports both formats. The team switches
> to it once Tâm agrees.

## 2. What you write: five parts

**(1) Port groups.** Write comments, not ports. Each comment gathers ports by name:

```systemverilog
module m_qnsc_wrap_apb_adv_timer import qnsc_pkg::*; (
/*AUTOINPUT("^i_clk\|^i_rst")*/                        // clock and reset
/*AUTOINPUT("^i_bus_apb")*/ /*AUTOOUTPUT("^o_bus_apb")*/ // APB
/*AUTOINPUT("^i_pad")*/     /*AUTOOUTPUT("^o_pad")*/     // pads
/*AUTOOUTPUT("^o_int")*/                                // interrupts
/*AUTOINOUT*/ /*AUTOINPUT*/ /*AUTOOUTPUT*/             // "Others": must end empty
);
/*AUTOWIRE*/                                           // internal wires, declared by emacs
```

Declare **no port by hand**. A port that is declared by hand leaves a trailing comma
before expansion, so the source is no longer valid SystemVerilog.

**(2) Added logic.** Write it by hand, named `r_*` (flop) or `w_*` (wire):

```systemverilog
logic [31:0] w_ext_sig;
assign w_ext_sig = {28'b0, w_tim_ext_sync};
```

**(3) Two settings.** `w_*` signals are internal and never become ports:

```systemverilog
/*AUTO_LISP(setq verilog-auto-input-ignore-regexp  "^w_")*/
/*AUTO_LISP(setq verilog-auto-output-ignore-regexp "^w_")*/
```

**(4) `AUTO_TEMPLATE`.** One rule per port of the instantiated module:
`.<its port>  (<our signal>)`.

```systemverilog
/* apb_adv_timer AUTO_TEMPLATE(
    .HCLK            (i_clk_peri),         // rename
    .dft_cg_enable_i (1'b0),               // tie off
    .ch_2_o          (),                   // leave open
    .events_o        (o_int_pwm[]),        // [] keeps the width
    .ch_0_o          (o_pad_pwm[3:0]),     // a slice: several ports make one
    .P\(ADDR\|WDATA\|WRITE\|SEL\|ENABLE\) (i_bus_apb_p@"(downcase (symbol-name '\1))"[]),
                                           // one regex rule for five ports
);*/
```

The first matching rule wins. `\(...\)` captures a part of the name, and `\1` reuses
it. More functions (`vl-dir`, `vl-width`, `vl-cell-name`, arithmetic in `[]`) are in the
quick guide.

**(5) Instance.** Give the name and parameters only. Take the parameters from `qnsc_pkg`:

```systemverilog
apb_adv_timer #(.APB_ADDR_WIDTH(C_APB_PADDR_WIDTH)) u_apb_adv_timer (/*AUTOINST*/);
```

For another instantiated module (for example `qnsc_sync`), add its own
`AUTO_TEMPLATE` and instance, **and add its file to `filelist_emacs.f`**.

## 3. What emacs writes

After `make wrap`, emacs owns two kinds of lines. **Never edit these by hand:**

- everything between `// Beginning of automatic …` and `// End of automatics`;
- the pin list inside `(/*AUTOINST*/ … )`, where each line ends in `// Templated`.

The next `make wrap` replaces them, and CI fails if the committed file differs.

## 4. The loop

```text
edit the source  →  make wrap BLOCK=<block>  →  read the result  →  repeat
```

After each `make wrap`, check:
- Every group lists the ports the MAS names.
- **"Others" is empty.** A port there has no rule: add a line to the `AUTO_TEMPLATE`.
- The instance has one `// Templated` line per port.

Then run `make check`.

## 5. Settings in every source file

At the end of the file, as in the template:

```systemverilog
// Local Variables:
// verilog-library-flags:("-f filelist_emacs.f")   // "-F emacs/filelist_emacs.f" in the one-file format
// verilog-library-extensions:(".v" ".sv")
// verilog-auto-star-expand: nil
// verilog-auto-inst-param-value: t                // instance parameters reach the widths; no sed
// indent-tabs-mode: nil                           // spaces, not tabs
// End:
```

## 6. When emacs fails

| Message or symptom | Fix |
|---|---|
| `Can't locate 'x' module definition` | Add `x`'s file to `filelist_emacs.f` |
| A port lands in "Others" | Add a rule for it to the `AUTO_TEMPLATE` |
| Widths show a parameter name (`[APB_ADDR_WIDTH-1:0]`) | Set the parameter in the instance `#(...)`; `verilog-auto-inst-param-value: t` substitutes it |
| An internal signal became a port | Name it `w_*`; the two `AUTO_LISP` settings exclude it |
| `Generated wrappers` fails in CI | Run `make wrap` and commit the result |
