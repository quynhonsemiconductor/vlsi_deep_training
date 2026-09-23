---
title: "TEMPLATE"
subtitle: "MICRO-ARCHITECTURE SPECIFICATION -- V0.1"
author: "QUY NHON SEMICONDUCTORS -- QNSC"
---

<!--
  QNSC micro-architecture specification -- canonical template.

  Copy this file to doc/src/QNSC_<BLOCK>_MAS.md, then add the pair
      ("QNSC_<BLOCK>_MAS", "<BLOCK>")
  to DOCS in doc/build_docs.py. Build with:  cd doc && python3 build_docs.py

  The three metadata lines above are the cover. Do not write a cover by hand and
  do not add a top-level "# <block> MAS" heading -- the title would then appear
  twice. `title` is the IP name, and the version in `subtitle` also fills the
  running header, so it has to match the last row of the revision table.

  Sections 1 to 3 and the two appendices are the team template
  (template/QNSC_Technical_Document_Format.docx) and are mandatory. Sections 4 to
  12 are what verification needs and the team template leaves to the author.

  Write NOTHING before the first heading. Pandoc puts the contents, the table of
  tables and the table of figures immediately after the cover, so any text above
  the first heading lands between the table of figures and the revision history,
  belonging to no section and looking like part of the figure list. Anything you
  want to say first goes in section 1.

  STYLE -- the one rule. Every sentence must be a claim somebody can write a test
  for. A specification is the contract between design and DV, so a sentence that
  cannot be tested is commentary and belongs in QNSC_<BLOCK>_DECISIONS.md, not
  here. Reasoning, rejected designs and the history of how a number was arrived
  at go in that file. Aim for 150-300 lines.

  Delete every one of these comments as you fill the file in.
-->

# Revision history

<!-- One line per version, never one paragraph.

     Keep this table SHORT. Measured on the interrupt map, twenty-two rows came
     to 13% of the whole document and sat in front of section 1 -- the same
     proportion the old prose changelog had, so nothing had been gained. A reader
     opens a specification to learn the design, not to learn how many times the
     author changed their mind.

     Two rules that keep it short:
       - the row says WHAT changed, in one clause. WHY goes in _DECISIONS.md.
       - after a rewrite, start the table again at the new version and point to
         _DECISIONS.md for what came before. A rewritten document's old history
         describes a document that no longer exists.

     Keep the five columns: they are the team template's. -->

The reasoning behind each change is in
[`QNSC_<BLOCK>_DECISIONS.md`](QNSC_<BLOCK>_DECISIONS.md).

| Version | Date | Author | Reviewer | Description of change |
|---|---|---|---|---|
| V0.1 | YYYY-MM-DD | Name | -- | First issue |

# 1. Overview

<!-- Two or three sentences. What the block does, and the one fact that shapes
     everything else about it. Then what it does NOT do -- that line prevents
     more misunderstanding than any other in the document. -->

# 2. Features

<!-- A short list. One line per property a reviewer would want confirmed.
     Anything stated here must be visible in section 7. -->

# 3. Block diagram

<!-- Reference an image in doc/img/. The caption is numbered automatically, so
     write only the text: ![Something](../img/fig_<block>.png)
     Say which clock and reset domain the block is in, and where it sits on the
     bus. Monochrome diagrams only. -->

# 4. IP used

<!-- If the block wraps upstream IP, one row per module, with the commit from
     vendor/manifest.yml -- a specification claim about upstream RTL is only true
     at a commit. If the block is in house, say so and leave the table empty:
     an empty table is the answer, not a missing section. -->

: Upstream IP used

| From | Module | Commit | Licence |
|---|---|---|---|
| -- | -- | -- | -- |

# 5. Interface

<!-- EVERY port. Name, direction, width, and the protocol or timing rule that
     governs it. This is what DV builds the driver and monitor from.
     Names follow QNSC_RTL_Design_Naming_Rule V1.0: i_/o_/io_ prefix,
     i_clk_<cluster>, i_rst_n_<cluster>, i_bus_apb_<sig>, i_int_<source>.
     If a port is absent by design -- no clock, no bus -- say so explicitly. -->

: <Block> interface

| Signal | Dir | Width | Description |
|---|---|---:|---|

# 6. Register map

<!-- Offset, field, bits, access type, reset value, description. The access type
     is mandatory and must be one of RW, RO, WO, W1C, RSVD: DV generates the
     reset-value and access-type tests from this column.
     If the block has no registers, say that and say where configuration lives
     instead. -->

: Register map

| Offset | Register | Field | Bits | Access | Reset | Description |
|---|---|---|---|---|---|---|

# 7. Functional behaviour

<!-- The longest section. One subsection per feature in section 2. Each paragraph
     should make one claim. State the error and boundary cases, not only the
     happy path: what is silently dropped, what is held, what is lost.
     Tables that restate util/qsoc_contract.yml are generated, not typed --
     see doc/tools/gen_doc_tables.py and use a <!-- gen:name --> region. -->

## 7.1 <Feature>

# 8. Instances

<!-- How many, and which parameter differs between them. A forked copy of a file
     is not an instance and is not acceptable. -->

# 9. What is not provided here, and who provides it

<!-- Function against location. This is where a reader finds out that the thing
     they expected in this block lives somewhere else, which is the most common
     way two owners build the same thing twice, or neither builds it. -->

: Functions this block does not provide

| Function | Where it lives |
|---|---|

# 10. Tie-offs

<!-- Every port tied to a constant, and why. A tie-off with no reason is an
     unfinished design decision. State the consequence for firmware if there
     is one. -->

: Tie-offs

| Port | Tied to | Why |
|---|---|---|

# 11. Requirements on others, and open items

<!-- What this block needs from another owner, naming the owner, and saying what
     it blocks. Then the limits you accept, stated rather than hidden -- an
     accepted limit written down is a decision; an unwritten one is a bug
     waiting to be found in silicon.
     Never close an ambiguity by reading your own RTL: the RTL may contain the
     same wrong assumption. Agree it with the owner and write it here. -->

: Requirements on other owners

| Item | Owner | What it blocks |
|---|---|---|

# 12. Verification

<!-- A numbered list of checks, one per claim above. If a claim cannot be turned
     into a check, it does not belong in this document. Include at least one
     check that fails if the design drifts from its own description -- for a
     combinational block, that no always_ff appears. -->

# Appendix A. Acronyms

: Acronyms

| Acronym | Description |
|---|---|

# Appendix B. First review

<!-- Review items and their resolution. A question closed in conversation but
     not written here will be asked again. -->

: First review

| Item | Reviewer | Response |
|---|---|---|
