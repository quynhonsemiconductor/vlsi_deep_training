# `doc/` — guides, rules, reference

Specifications are **not** kept here: the team writes and reads them
(`QNSC_<BLOCK>_MAS`, `_DECISIONS`) on the team SharePoint. What this repository
keeps is the inter-block contract,
[`util/qsoc_contract.yml`](../util/qsoc_contract.yml), which every number in a
specification must agree with — see [`CONTRIBUTING.md`, "Specifications"](../CONTRIBUTING.md).

Each folder below answers one question.

```
doc/
  README.md          this index
  BLOCKS.md          every block: directory, owner, specification
  guides/            how do I work here?          -- team how-to
  rules/             what is mandatory?           -- Naming Rule, EMACS guide (owner: Tâm)
  reference/         what did the teacher give us? -- HAS, chip diagram
  figures/           img/fig_qsoc_full*           -- the root README block diagram
  present/           personal notes, never committed
```

| Folder | Contents | Edit it? |
|---|---|---|
| [`guides/`](guides) | [`GETTING_STARTED.md`](guides/GETTING_STARTED.md): setup to merged PR, for any code. [`EMACS_AUTO.md`](guides/EMACS_AUTO.md): writing a module that instantiates others | yes |
| [`rules/`](rules) | Naming Rule (`.docx` source and `.pdf` release) and the EMACS quick guide. See [`rules/README.md`](rules/README.md) | Tâm reviews every change |
| [`reference/`](reference) | `QSOC_HAS_Report_EN_v4_final.docx`, `QNSC_Diagram.drawio`, `VLSI_SCRC.drawio`, `VLSI_SYSDBG.drawio`: material from the teacher | no |
| `figures/` | `img/fig_qsoc_full.svg` and `img/fig_qsoc_full_mono.png`, the root README block diagram | generated |
| [`present/`](present) | Keep your own study or presentation notes here. The folder is never committed | yours |

## Notes

- Keep your own study or presentation notes in `doc/present/`. The folder is never
  committed.
- Do not add files received from other owners (their `.docx`, `.xlsx`).
- The Markdown specification sources that used to live in `doc/specs/`, and the
  toolchain that built `.docx` from them in `doc/build/`, were removed from the
  repository. They remain in the git history for reference, and a copy lives on
  the team SharePoint.
