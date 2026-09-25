# `doc/rules/` — team rules

The rules every block follows. **This directory is their home**: they were first
written in Tâm's personal workspace `MCU_guide_ws` (commit `3d66c27`, 2026-09-15)
and moved here once the team repository existed. Edit them here only.

| File | What it is | Enforced by |
|---|---|---|
| `QNSC_RTL_Design_Naming_Rule.docx` | Naming Rule, editable source | -- |
| `QNSC_RTL_Design_Naming_Rule.pdf` | Naming Rule **V1.0**, the released version | `flow/lint/naming_rules.yml` + `naming_check.py` (`make naming`) |
| `EMACS_quick_guide.pdf` | How to write a wrapper with emacs verilog-mode: the template and every template function | `flow/emacs/template.src.sv.in`, `make new-wrap`, `make wrap-check` |

How the rules are applied in this repository, and the decisions for the cases the
rule leaves open, are in [`design/README.md`](../../design/README.md#naming).

## Changing a rule

Owner: Tâm (`@Stork1323`); a change needs his review.

1. Edit the `.docx`, raise the version in its revision table, and export the `.pdf`.
2. In the **same pull request**, update what enforces it: `flow/lint/naming_rules.yml`
   (its `version:` and patterns), the naming table in `design/README.md`, and the
   emacs template if the guide changed.
3. Commit the `.docx` and the `.pdf` together. They are sources, not build output.
