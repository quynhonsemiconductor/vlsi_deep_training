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

    def document(xml):
        xml = re.sub(r'(<w:tblStyle w:val=")Table(")', r"\1TableGrid\2", xml)

        # Direct formatting, so alignment does not depend on how the reader
        # resolves style inheritance from Normal (which the template justifies).
        def left(m):
            para = m.group(0)
            if not any('w:val="%s"' % n in para for n in LEFT_STYLES):
                return para
            if re.search(r"<w:jc\b", para):
                return para
            return para.replace("</w:pPr>", '<w:jc w:val="left"/></w:pPr>', 1)

        return re.sub(r"<w:p\b[^>]*>.*?</w:p>", left, xml, flags=re.S)

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
    print("built %s.docx  (%s)" % (stem, title))


if __name__ == "__main__":
    make_reference()
    for stem, title in DOCS:
        build(stem, title)
