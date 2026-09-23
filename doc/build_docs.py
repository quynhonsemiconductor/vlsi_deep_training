#!/usr/bin/env python3
"""Build the QNSC micro-architecture specifications from the markdown sources.

Three steps, all reproducible:

1. Derive a reference document from the QNSC template:
   - strip the automatic numbering from Heading1..6, because the markdown
     sources carry their own section numbers,
   - left align the Compact style, which the tables use; it otherwise inherits
     justified alignment from Normal and stretches text inside narrow cells.
2. Run pandoc with that reference document.
3. Post-process: fill the "<IP name>" header placeholder, blank the corrupted
   footer runs inherited from the template, and point tables at TableGrid.

Usage:  python3 build_docs.py
"""
import os
import re
import shutil
import subprocess
import zipfile

TEMPLATE = "template/QNSC_Technical_Document_Format.docx"
REFERENCE = "template/QNSC_Reference_NoAutoNum.docx"
DOCS = [
    ("QNSC_RAM_MAS", "RAM"),
    ("QNSC_SYSDBG_MAS", "SYSDBG -- Debugger"),
    ("QNSC_Interrupt_Map_MAS", "Interrupt Map"),
    ("QNSC_TIMER_MAS", "TIMER"),
    ("QNSC_PWM_MAS", "PWM"),
]
HEADINGS = ["Heading%d" % i for i in range(1, 7)]


def rewrite(path, transforms):
    """Rewrite parts of a docx in place. transforms: {name_pattern: func(str)->str}"""
    zin = zipfile.ZipFile(path)
    items = [(i, zin.read(i.filename)) for i in zin.infolist()]
    zin.close()
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as out:
        for info, data in items:
            for pattern, func in transforms.items():
                if re.fullmatch(pattern, info.filename):
                    data = func(data.decode("utf-8")).encode("utf-8")
                    break
            out.writestr(info, data)


def make_reference():
    shutil.copy(TEMPLATE, REFERENCE)

    def styles(xml):
        for h in HEADINGS:
            xml = re.sub(r'<w:style [^>]*w:styleId="%s">.*?</w:style>' % h,
                         lambda m: re.sub(r"<w:numPr>.*?</w:numPr>", "", m.group(0), flags=re.S),
                         xml, flags=re.S)
        xml = re.sub(r'(<w:style [^>]*w:styleId="Compact">.*?<w:pPr>.*?)(</w:pPr>)',
                     r'\1<w:jc w:val="left"/>\2', xml, flags=re.S)

        # The template defines no indent on the TOC levels, so every entry sits
        # flush left and the hierarchy is invisible. Indent level 2 and deeper.
        for lvl, twips in (("TOC2", 360), ("TOC3", 720), ("TOC4", 1080)):
            xml = re.sub(
                r'(<w:style [^>]*w:styleId="%s">)(.*?)(</w:style>)' % lvl,
                lambda m, t=twips: m.group(1) + (
                    re.sub(r'(<w:pPr>)', r'\1<w:ind w:left="%d"/>' % t, m.group(2), count=1)
                    if "<w:pPr>" in m.group(2)
                    else re.sub(r'(<w:name [^>]*/>)', r'\1<w:pPr><w:ind w:left="%d"/></w:pPr>' % t,
                                m.group(2), count=1)
                ) + m.group(3),
                xml, flags=re.S)
        return xml

    rewrite(REFERENCE, {r"word/styles\.xml": styles})
    print("built", REFERENCE)


# --------------------------------------------------------------------------
# front matter: title page, numbered captions, table of tables and figures
#
# The QNSC template carries all four, and pandoc produces none of them from
# plain markdown: it has no cover concept, and it writes a caption as the bare
# text with no "Table 2-1." prefix. They are added here rather than typed into
# every source, so the numbering cannot go stale when a table is inserted.
#
# Word fields are not used. Pandoc's own table of contents is a static list --
# checked, there is no TOC field in the output -- so a field here would leave a
# document whose contents page is filled in and whose table of tables says
# "update this field". Static keeps the three consistent.
# --------------------------------------------------------------------------

# Caption styles as pandoc actually emits them, confirmed by building a probe
# document: a table caption becomes Tablecaption0 and sits *above* the table,
# a figure caption becomes ImageCaption and sits *below* the image. The
# unsuffixed names are included because the 0 is a collision suffix against the
# template's own Tablecaption, which pandoc will not add if that changes.
TABLE_CAPTION = ("Tablecaption0", "Tablecaption", "TableCaption")
FIGURE_CAPTION = ("ImageCaption", "FigureCaption")

PARA = re.compile(r"<w:p\b[^>]*>.*?</w:p>", re.S)


def _style(para):
    m = re.search(r'w:pStyle w:val="([^"]+)"', para)
    return m.group(1) if m else ""


def _text(para):
    return "".join(re.findall(r"<w:t(?:\s[^>]*)?>([^<]*)</w:t>", para))


def _para(text, style=None, size=None, bold=False, align="left",
          page_break=False, indent=0):
    """One paragraph. Formatting is direct rather than by style, because the
    template justifies Normal and these need their own alignment."""
    ppr = ['<w:pPr>']
    if style:
        ppr.append('<w:pStyle w:val="%s"/>' % style)
    if indent:
        ppr.append('<w:ind w:left="%d"/>' % indent)
    ppr.append('<w:jc w:val="%s"/>' % align)
    rpr = ""
    if bold or size:
        rpr = "<w:rPr>%s%s</w:rPr>" % (
            "<w:b/>" if bold else "",
            '<w:sz w:val="%d"/><w:szCs w:val="%d"/>' % (size, size) if size else "")
    if rpr:
        ppr.append(rpr)
    ppr.append("</w:pPr>")
    run = '<w:r>%s<w:t xml:space="preserve">%s</w:t></w:r>' % (
        rpr, text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
    brk = ('<w:r><w:br w:type="page"/></w:r>') if page_break else ""
    return "<w:p>" + "".join(ppr) + run + brk + "</w:p>"


def number_captions(xml):
    """Prefix every caption with "Table N-M." or "Figure N-M.", numbering within
    the section, and return the two lists for the front matter.

    The section number is read out of the heading text rather than counted,
    because the markdown sources carry their own numbers and an appendix is
    lettered, not numbered."""
    tables, figures = [], []
    section = "0"
    counters = {}

    def walk(m):
        nonlocal section
        para, st, text = m.group(0), _style(m.group(0)), _text(m.group(0))
        if st.startswith("Heading"):
            h = re.match(r"(?:Appendix\s+([A-Z])|(\d+))\s*\.", text.strip())
            if h:
                section = h.group(1) or h.group(2)
            return para
        kind = ("Table" if st in TABLE_CAPTION else
                "Figure" if st in FIGURE_CAPTION else None)
        if not kind or not text.strip():
            return para
        key = (kind, section)
        counters[key] = counters.get(key, 0) + 1
        label = "%s %s-%d. " % (kind, section, counters[key])
        (tables if kind == "Table" else figures).append(label + text.strip())
        # Prefix the first run only, so inline formatting in the rest survives.
        return re.sub(r"(<w:t(?:\s[^>]*)?>)",
                      lambda r: r.group(1) + label, para, count=1)

    return PARA.sub(walk, xml), tables, figures


def insert_front_lists(xml, tables, figures):
    """Put Table of Tables and Table of Figures after pandoc's contents.

    Anchored on the paragraph carrying the TOC field instruction, because that is
    what pandoc emits -- a field for Word to populate, not a list of TOC1
    paragraphs, so there is no rendered entry to attach to.

    These two lists are static text while the contents above them is a field.
    That is deliberate: a "TOC \\c Table" field collects SEQ fields, and these
    captions are plain numbered text, so the field would come up empty. Static
    also means the lists are right in any reader, without the document having to
    be opened in Word and refreshed."""
    if not tables and not figures:
        return xml
    anchor = None
    for para in PARA.findall(xml):
        if re.search(r"<w:instrText[^>]*>[^<]*TOC", para):
            anchor = para
    if anchor is None:
        return xml
    block = []
    for heading, entries in (("Table of Tables", tables),
                             ("Table of Figures", figures)):
        if not entries:
            continue
        block.append(_para(heading, style="TOCHeading"))
        block += [_para(e, style="TOC1", indent=180) for e in entries]
    return xml.replace(anchor, anchor + "".join(block), 1)


def cover_page_break(xml):
    """Put the cover on its own page.

    The cover itself comes from the pandoc metadata block at the top of each
    source, which renders through the template's own Title, Subtitle and
    Author styles -- building one here as well produced two covers. Pandoc
    just does not break the page afterwards."""
    paras = PARA.findall(xml)
    last = None
    for para in paras[:8]:
        if _style(para) in ("Title", "Subtitle", "Author"):
            last = para
    if last is None:
        return xml
    return xml.replace(
        last, last + '<w:p><w:r><w:br w:type="page"/></w:r></w:p>', 1)


def verify(path):
    """Every XML part must parse. Word rejects a malformed part outright, while
    some readers silently repair it, so this has to be checked at build time."""
    import xml.etree.ElementTree as ET
    z = zipfile.ZipFile(path)
    broken = []
    for n in z.namelist():
        if n.endswith((".xml", ".rels")):
            try:
                ET.fromstring(z.read(n))
            except Exception as e:
                broken.append("%s: %s" % (n, e))
    z.close()
    if broken:
        raise SystemExit("XML KHONG HOP LE trong %s:\n  " % path + "\n  ".join(broken))


def build(stem, title):
    subprocess.run(["pandoc", "src/%s.md" % stem, "-o", "%s.docx" % stem,
                    "--reference-doc=" + REFERENCE, "--toc", "--toc-depth=2",
                    "--resource-path=.:src:img"], check=True)

    def footer(xml):
        # (?:\s[^>]*)? is required: a bare "<w:t[^>]*>" also matches "<w:tab .../>"
        # and would swallow real elements up to the next </w:t>.
        return re.sub(r"<w:t(?:\s[^>]*)?>([^<]*)</w:t>",
                      lambda m: "<w:t></w:t>"
                      if m.group(1).lstrip().startswith("&lt;w:") or "March 20, 2026" in m.group(1)
                      else m.group(0), xml)

    def header(xml):
        return re.sub(r"(<w:t(?:\s[^>]*)?>)&lt;IP name&gt;([^<]*)(</w:t>)",
                      lambda m: m.group(1) + title + m.group(2) + m.group(3), xml)

    LEFT_STYLES = ("SourceCode", "Compact", "ImageCaption", "CaptionedFigure")
    counts = {"tables": 0, "figures": 0}

    def document(xml):
        xml = re.sub(r'(<w:tblStyle w:val=")Table(")', r"\1TableGrid\2", xml)

        # Order matters: number the captions first, because the two front lists
        # are built from the numbered text, and add the cover last so its
        # paragraphs are not scanned for captions or left alignment.
        xml, tables, figures = number_captions(xml)
        xml = insert_front_lists(xml, tables, figures)

        # Direct formatting, so alignment does not depend on how the reader
        # resolves style inheritance from Normal (which the template justifies).
        def left(m):
            para = m.group(0)
            if not any('w:val="%s"' % n in para for n in LEFT_STYLES):
                return para
            if re.search(r"<w:jc\b", para):
                return para
            return para.replace("</w:pPr>", '<w:jc w:val="left"/></w:pPr>', 1)

        xml = re.sub(r"<w:p\b[^>]*>.*?</w:p>", left, xml, flags=re.S)
        counts["tables"], counts["figures"] = len(tables), len(figures)
        return cover_page_break(xml)

    def styles(xml):
        # Styles pandoc creates in the output are based on Normal, which the QNSC
        # template justifies. Justified code and captions stretch to the margin,
        # so force left alignment on them.
        for name in ("SourceCode", "Compact", "ImageCaption", "CaptionedFigure"):
            def left(m):
                block = m.group(0)
                if re.search(r'<w:jc w:val="\w+"\s*/>', block):
                    return re.sub(r'<w:jc w:val="\w+"\s*/>', '<w:jc w:val="left"/>', block)
                if "<w:pPr>" in block:
                    return block.replace("</w:pPr>", '<w:jc w:val="left"/></w:pPr>', 1)
                return block.replace("</w:style>", "", 1) + "</w:style>" if False else re.sub(
                    r'(<w:name [^>]*/>)', r'\1<w:pPr><w:jc w:val="left"/></w:pPr>', block, count=1)
            xml = re.sub(r'<w:style [^>]*?w:styleId="%s"[^>]*>.*?</w:style>' % name,
                         left, xml, flags=re.S)

        # The QNSC template has no VerbatimChar, so pandoc's code runs fall back
        # to Times New Roman: "==" then renders as one stacked glyph. Give code a
        # monospace face. Courier New is present on both macOS and Windows.
        mono = ('<w:rFonts w:ascii="Courier New" w:hAnsi="Courier New" '
                'w:cs="Courier New"/><w:sz w:val="20"/><w:szCs w:val="20"/>')
        if 'w:styleId="VerbatimChar"' not in xml:
            xml = xml.replace("</w:styles>",
                              '<w:style w:type="character" w:customStyle="1" '
                              'w:styleId="VerbatimChar"><w:name w:val="Verbatim Char"/>'
                              '<w:basedOn w:val="DefaultParagraphFont"/>'
                              '<w:rPr>' + mono + "</w:rPr></w:style></w:styles>")

        def add_mono(m):
            block = m.group(0)
            if "<w:rPr>" in block:
                return block.replace("<w:rPr>", "<w:rPr>" + mono, 1)
            return block.replace("</w:style>", "<w:rPr>" + mono + "</w:rPr></w:style>", 1)

        return re.sub(r'<w:style [^>]*?w:styleId="SourceCode"[^>]*>.*?</w:style>',
                      add_mono, xml, flags=re.S)

    rewrite("%s.docx" % stem, {r"word/footer\d+\.xml": footer,
                               r"word/header\d+\.xml": header,
                               r"word/document\.xml": document,
                               r"word/styles\.xml": styles})
    verify("%s.docx" % stem)
    print("built %s.docx  (%s)  %d table, %d figure"
          % (stem, title, counts["tables"], counts["figures"]))


if __name__ == "__main__":
    make_reference()
    for stem, title in DOCS:
        build(stem, title)
