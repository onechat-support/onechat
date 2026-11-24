#!/usr/bin/env python3
"""Convierte un Markdown del proyecto (docs/) a PDF con la
identidad de ONEchat. Uso:
  python3 tools/build_pdf.py docs/ARCHIVO.md salida.pdf "Pie de página"
Requiere: pip install fpdf2 (fuentes DejaVu/Liberation del sistema).
"""
import re
import sys

from fpdf import FPDF

SRC, OUT, FOOTER = sys.argv[1], sys.argv[2], sys.argv[3]
FONT_DIR = "/usr/share/fonts/truetype/dejavu/"
ITALIC = "/usr/share/fonts/truetype/liberation/LiberationSans-Italic.ttf"


class Doc(FPDF):
    def footer(self):
        self.set_y(-14)
        self.set_font("dejavu", "", 8)
        self.set_text_color(130, 130, 130)
        self.cell(0, 8, FOOTER, align="L")
        self.cell(0, 8, f"{self.page_no()}/{{nb}}", align="R")


pdf = Doc(orientation="P", unit="mm", format="A4")
pdf.add_font("dejavu", "", FONT_DIR + "DejaVuSans.ttf")
pdf.add_font("dejavu", "B", FONT_DIR + "DejaVuSans-Bold.ttf")
pdf.add_font("dejavu", "I", ITALIC)
pdf.set_auto_page_break(True, margin=18)
pdf.set_margins(18, 16, 18)
pdf.add_page()

lines = open(SRC, encoding="utf-8").read().replace("⚔️", "").split("\n")


def para(text, size=10.5, bold=False, space_after=2.2):
    pdf.set_font("dejavu", "B" if bold else "", size)
    pdf.set_text_color(30, 30, 30)
    pdf.multi_cell(0, 5.4, text, markdown=True)
    pdf.ln(space_after)


i = 0
first_title = True
while i < len(lines):
    ln = lines[i].rstrip()
    i += 1
    if not ln.strip():
        continue
    if ln.startswith("|"):
        rows = []
        while i - 1 < len(lines) and ln.startswith("|"):
            cells = [c.strip() for c in ln.strip().strip("|").split("|")]
            if not all(set(c) <= set("-: ") for c in cells):
                rows.append(cells)
            if i < len(lines):
                ln = lines[i].rstrip()
                i += 1
            else:
                break
        if rows:
            ncols = len(rows[0])
            widths = {2: (52, 122), 3: (34, 30, 110),
                      4: (28, 38, 34, 74)}.get(
                          ncols, tuple([174 // ncols] * ncols))
            pdf.set_font("dejavu", "", 9)
            with pdf.table(col_widths=widths, text_align="LEFT",
                           line_height=4.6,
                           cell_fill_color=(240, 244, 244),
                           cell_fill_mode="ROWS",
                           first_row_as_headings=True) as table:
                for r in rows:
                    row = table.row()
                    for c in r:
                        row.cell(c)
            pdf.ln(3)
        continue
    if ln.startswith("# "):
        if first_title:
            pdf.ln(10)
            pdf.set_font("dejavu", "B", 24)
            pdf.set_text_color(0, 140, 122)
            pdf.multi_cell(0, 11, ln[2:].replace(" — ", "\n— "))
            pdf.ln(4)
            first_title = False
        else:
            para(ln[2:], size=15, bold=True, space_after=3)
        continue
    if ln.startswith("## "):
        pdf.ln(3)
        pdf.set_font("dejavu", "B", 14)
        pdf.set_text_color(0, 140, 122)
        pdf.multi_cell(0, 7, ln[3:], markdown=True)
        pdf.set_draw_color(0, 194, 168)
        pdf.set_line_width(0.5)
        y = pdf.get_y() + 1
        pdf.line(pdf.l_margin, y, pdf.w - pdf.r_margin, y)
        pdf.ln(4)
        continue
    if ln.startswith("### "):
        para(ln[4:], size=12, bold=True)
        continue
    if ln.strip() == "---":
        pdf.ln(2)
        continue
    if ln.startswith("- "):
        pdf.set_font("dejavu", "", 10.5)
        pdf.set_text_color(30, 30, 30)
        pdf.cell(6, 5.4, "•")
        pdf.multi_cell(0, 5.4, ln[2:], markdown=True)
        pdf.ln(1.2)
        continue
    if re.match(r"^\d+\. ", ln):
        para(ln, space_after=1.2)
        continue
    if ln.startswith("*") and ln.endswith("*") and len(ln) > 2:
        pdf.set_font("dejavu", "I", 9.5)
        pdf.set_text_color(90, 90, 90)
        pdf.multi_cell(0, 5.2, ln.strip("*"))
        pdf.ln(2)
        continue
    buf = ln
    while (i < len(lines) and lines[i].strip()
           and not lines[i].startswith(("#", "- ", "|"))
           and not re.match(r"^\d+\. ", lines[i])
           and lines[i].strip() != "---"):
        buf += " " + lines[i].strip()
        i += 1
    para(buf)

pdf.output(OUT)
print("PDF generado:", OUT, "páginas:", pdf.page_no())
