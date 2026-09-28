# `doc/` — guides, rules, specifications

Each folder answers one question.

```
doc/
  README.md          this index
  BLOCKS.md          every block: directory, owner, specification
  guides/            how do I work here?          -- team how-to
  rules/             what is mandatory?           -- Naming Rule, EMACS guide (owner: Tâm)
  specs/             what must my block do?       -- MAS and DECISIONS, Markdown source
    docx/            the same specifications as .docx, generated
  reference/         what did the teacher give us? -- HAS, chip diagram
  figures/           the diagrams                 -- img/ (rendered), drawio/ (editable)
  build/             how are the documents built? -- build_docs.py, tools/, template/
  present/           personal notes, never committed
```

| Folder | Contents | Edit it? |
|---|---|---|
| [`guides/`](guides) | [`GETTING_STARTED.md`](guides/GETTING_STARTED.md): setup to merged PR, for any code. [`EMACS_AUTO.md`](guides/EMACS_AUTO.md): writing a module that instantiates others | yes |
| [`rules/`](rules) | Naming Rule (`.docx` source and `.pdf` release) and the EMACS quick guide. See [`rules/README.md`](rules/README.md) | Tâm reviews every change |
| [`specs/`](specs) | `QNSC_<BLOCK>_MAS.md` (the specification) and `QNSC_<BLOCK>_DECISIONS.md` (why), plus `QNSC_TEMPLATE_MAS.md`. **The Markdown is the source of truth** | yes |
| `specs/docx/` | The `.docx` built from `specs/*.md`, committed so a reader without pandoc can open them | generated |
| [`reference/`](reference) | `QSOC_HAS_Report_EN_v4_final.docx`, `QNSC_Diagram.drawio`, `VLSI_SCRC.drawio`, `VLSI_SYSDBG.drawio`: material from the teacher | no |
| [`figures/`](figures) | `img/*.png`, `*.svg` (rendered, committed) and `drawio/*.drawio` (editable), written by the scripts in `build/tools/` | generated |
| [`build/`](build) | `build_docs.py`; `tools/` (figure scripts, `diagen.py`, `gen_doc_tables.py`, `svg_mono.py`); `template/` (the pandoc reference template) | when the build changes |

## Rules for generated files

- Commit a `specs/docx/*.docx` **only when its `specs/*.md` changed.** A `.docx` is a
  zip, so every rebuild changes its bytes even when the content does not. After
  `make docs`, put back the untouched ones with `git checkout -- doc/specs/docx/<NAME>.docx`.
- Commit a rendered `figures/img/*` together with the script or drawio change that
  produced it.
- Keep your own study or presentation notes in `doc/present/`. Links such as
  `../figures/img/...` work from there, and the folder is never committed.
- Do not add files received from other owners (their `.docx`, `.xlsx`).

## Build the specifications

Needs `pandoc`. From the repository root:

```bash
make docs          # doc/specs/*.md -> doc/specs/docx/*.docx (the DOCS list in build_docs.py)
make tables        # the <!-- gen:... --> tables in specs match util/qsoc_contract.yml
```

CI runs both (*Specifications build and check*), so a broken source or template
fails the PR.

## Regenerate a diagram

Only when a diagram changes. Each script describes its figures once in Python;
`build/tools/diagen.py` writes the editable `.drawio`, the `.svg` and the `.png`
(through `rsvg-convert`) into `figures/`. CI does not render figures; it uses the
committed ones.

| Script (`doc/build/tools/`) | Figures | Used by |
|---|---|---|
| `build_ram_block.py` | `fig_ram_simple` | RAM MAS |
| `build_intr_map.py` | `fig_intr_map`, `fig_intr_levels` | Interrupt Map MAS, DECISIONS |
| `build_timer_pwm.py` | `fig_timer_block`, `fig_timer_inside`, `fig_pwm_block` | TIMER, PWM MAS |
| `build_sysdbg_mas.py` | `fig_sysdbg_block`, `fig_sysdbg_handshake`, `fig_sysdbg_boot_wiring` | SYSDBG MAS |
| `build_sysdbg_design.py`, `build_sysdbg_ports.py` | the V1.x SYSDBG figures | SYSDBG DECISIONS |
| `build_qsoc_mem.py` | `fig_qsoc_mem` | RAM and SYSDBG DECISIONS |
| `build_scrc.py` | `fig_scrc_*` (7 figures), `wave_scrc_*` (4 timing diagrams) | SCRC MAS |
| `build_syscsr.py` | `fig_syscsr_block`, `fig_syscsr_regs`, `wave_syscsr_cause` | SYSCSR MAS |
| `build_rom.py` | `fig_rom_block`, `fig_rom_layout`, `wave_rom_read`, `wave_rom_image`, `wave_rom_write` | ROM MAS |
| `build_boot.py` | `fig_boot_path`, `fig_boot_frame`, `fig_boot_flow`, `fig_boot_seq` | BOOT SPEC |
| `build_dma.py` | `fig_dma_block`, `fig_dma_flow`, `fig_dma_regs`, `wave_dma_job` | DMA MAS |
| `regfig.py` | the register bit-field renderer `build_syscsr.py` uses | any MAS |
| `wavegen.py` | the timing-diagram renderer `build_scrc.py` uses; monochrome, `.svg` + `.png` | any MAS |
| `svg_mono.py` | `fig_qsoc_full_mono` from `fig_qsoc_full.svg` | root README |

```bash
python3 doc/build/tools/build_timer_pwm.py      # any script runs from anywhere
```

## Adding a specification

1. Write `specs/<NAME>.md`, starting from `specs/QNSC_TEMPLATE_MAS.md`. Link figures
   as `../figures/img/<fig>.png`.
2. Add `("<NAME>", "<Header label>")` to `DOCS` in `build/build_docs.py`.
3. For a diagram, add `build/tools/build_<name>.py`.
4. Run `make docs`. Commit the `.md`, the script, the figures and the new `.docx`.
