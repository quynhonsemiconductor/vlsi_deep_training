# `doc/` — QSOC specifications

Micro-architecture specifications (MAS) for the blocks owned here, plus the
toolchain that builds them. **The source of truth is Markdown, not the `.docx`.**

## What is tracked, and what is not

| Path | Role | Tracked |
|------|------|---------|
| `src/*.md` | Spec source (the truth) | ✅ |
| `template/QNSC_Technical_Document_Format.docx` | pandoc reference template | ✅ |
| `tools/*.py`, `diagen.py` | Diagram generators | ✅ |
| `drawio/*.drawio` | Editable diagram sources | ✅ |
| `img/*.png`, `*.svg` | Rendered diagrams (committed so specs are readable without the drawio CLI) | ✅ |
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
python3 build_docs.py
```

Produces one `.docx` per entry in the `DOCS` list in `build_docs.py`. This is
the exact step CI runs (`RTL · CI` → *Specifications build and check*), so a
broken source or template fails the PR.

## Regenerate the diagrams (`img/` from `drawio/`)

Only needed when a diagram changes. Needs the **drawio CLI** (`drawio` /
`drawio-desktop`), which is why this is a manual step and **not** in CI — CI
consumes the committed `img/` instead of rendering it. Each script is
self-contained:

```bash
python3 tools/build_ram_block.py      # -> img/fig_ram_simple.* + drawio/QNSC_RAM_Block.drawio
python3 tools/build_intr_map.py       # interrupt map figures
python3 tools/build_sysdbg_design.py  # etc.
```

Paths in the scripts are relative to `doc/`, so they run from anywhere.

## Adding a spec

1. Write `src/<NAME>.md`.
2. Add `("<NAME>", "<Header label>")` to `DOCS` in `build_docs.py`.
3. If it has diagrams, add a `tools/build_<name>.py` and reference the rendered
   `img/*.png` from the markdown.
4. Run `build_docs.py` to confirm it builds. Commit the `.md`, drawio, img, and
   script — never the `.docx`.
