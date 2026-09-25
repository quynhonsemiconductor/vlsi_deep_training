# `doc/` — QSOC specifications

Micro-architecture specifications (MAS) for the blocks owned here, plus the
toolchain that builds them. **The source of truth is Markdown, not the `.docx`.**

## What is tracked, and what is not

| Path | Role | Tracked |
|------|------|---------|
| `src/*.md` | Spec source (the truth) | ✅ |
| `GETTING_STARTED.md`, `EMACS_AUTO.md` | Team guides: setup to merged PR; writing modules with emacs AUTOs | ✅ |
| `rules/` | Team rules: Naming Rule (`.docx` source + `.pdf` release) and the EMACS quick guide. Sources, owned by Tâm -- see [`rules/README.md`](rules/README.md) | ✅ |
| `template/QNSC_Technical_Document_Format.docx` | pandoc reference template | ✅ |
| `tools/*.py` | Diagram generators and the contract-table generator | ✅ |
| `drawio/*.drawio` | Editable diagram sources | ✅ |
| `img/*.png`, `*.svg` | Rendered diagrams (committed so specs are readable without running the scripts) | ✅ |
| `build_docs.py` | Builds the `.docx` specs from `src/*.md` | ✅ |
| `*.docx` (the specs) | **Generated** by `build_docs.py`, committed so a reviewer without pandoc can open them | ✅ |
| `template/QNSC_Reference_NoAutoNum.docx` | Build intermediate | ❌ gitignored |
| `present/` | Personal presentation notes and their figures | ❌ gitignored |
| Files received from other owners (their `.docx`, `.xlsx`) | Not a source of this repository | ❌ do not add |

**Rules for the generated files:**

- Commit a `.docx` **only when its `src/*.md` changed.** A `.docx` is a zip, so every
  rebuild changes its bytes even when the content does not. After `build_docs.py`,
  put back the untouched ones with `git checkout -- doc/<NAME>.docx`.
- Commit a rendered `img/*.png` / `*.svg` together with the script or drawio change
  that produced it.
- Keep your own study or presentation notes in `doc/present/`. It sits next to the
  specifications, so relative links such as `../img/...` still work, but it is never
  committed.

## Blocks documented here

`QNSC_RAM_MAS`, `QNSC_SYSDBG_MAS`, `QNSC_Interrupt_Map_MAS`, `QNSC_TIMER_MAS`,
`QNSC_PWM_MAS` — the five blocks owned in `design/`. Each block's README links to
its spec.

## Build the specs (`.docx` from `.md`)

Needs `pandoc`. From this directory:

```bash
python3 build_docs.py        # or, from the repository root: make docs
```

Produces one `.docx` per entry in the `DOCS` list in `build_docs.py`. This is
the exact step CI runs (`RTL · CI` → *Specifications build and check*), so a
broken source or template fails the PR.

## Regenerate the diagrams (`img/` and `drawio/` from `tools/`)

Only needed when a diagram changes. Each script describes its figures once in
Python; `tools/diagen.py` writes the editable `.drawio`, the `.svg`, and the
`.png` (through `rsvg-convert`). CI does not render; it uses the committed `img/`.

| Script | Figures | Used by |
|---|---|---|
| `tools/build_ram_block.py` | `fig_ram_simple` | RAM MAS |
| `tools/build_intr_map.py` | `fig_intr_map`, `fig_intr_levels` | Interrupt Map MAS, DECISIONS |
| `tools/build_timer_pwm.py` | `fig_timer_block`, `fig_timer_inside`, `fig_pwm_block` | TIMER, PWM MAS |
| `tools/build_sysdbg_mas.py` | `fig_sysdbg_block`, `fig_sysdbg_handshake`, `fig_sysdbg_boot_wiring` | SYSDBG MAS |
| `tools/build_sysdbg_design.py`, `tools/build_sysdbg_ports.py` | the V1.x SYSDBG figures | SYSDBG DECISIONS |
| `tools/build_qsoc_mem.py` | `fig_qsoc_mem` | RAM and SYSDBG DECISIONS |
| `tools/svg_mono.py` | `fig_qsoc_full_mono` from `fig_qsoc_full.svg` | root README |

`tools/gen_doc_tables.py` rewrites the `<!-- gen:... -->` tables in `src/*.md`
from `util/qsoc_contract.yml`; CI checks them with `--check` (`make tables`).

Paths in the scripts are relative to `doc/`, so they run from anywhere.

## Adding a spec

1. Write `src/<NAME>.md`.
2. Add `("<NAME>", "<Header label>")` to `DOCS` in `build_docs.py`.
3. If it has diagrams, add a `tools/build_<name>.py` and reference the rendered
   `img/*.png` from the markdown.
4. Run `build_docs.py` to confirm it builds. Commit the `.md`, drawio, img,
   script, and the new `.docx` (the rules above).
