#!/usr/bin/env python3
"""Render the ETHGlobal submission's description field as one pasteable plain-text file.

The field does not render Markdown — the description actually filed at ETHOnline is prose with
no asterisks and no backticks — and the rules require the pre-existing-work disclosure to be
reproduced *in* that field. So the description is the narrative followed by the whole of
DISCLOSURE.md, and neither half is retyped: this assembles both, so the form and the repository
cannot silently disagree.

    python3 docs/tokyo-2026/build-description.py     # writes docs/tokyo-2026/DESCRIPTION.txt

Paste DESCRIPTION.txt into the description field. All of it, in one go.
"""

import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
FORM = HERE / "SUBMISSION-FORM.md"
DISCLOSURE = HERE / "DISCLOSURE.md"
OUT = HERE / "DESCRIPTION.txt"


def narrative() -> str:
    """The §4 copy block — the one fenced block in the Description section."""
    text = FORM.read_text()
    section = text[text.index("## 4. Description"): text.index("## 5. How it's made")]
    blocks = re.findall(r"~~~text\n(.*?)~~~", section, re.S)
    if len(blocks) != 1:
        sys.exit(f"expected exactly one copy block in §4, found {len(blocks)}")
    return blocks[0].strip()


def plain(md: str) -> str:
    """Markdown -> the plain prose the field actually stores.

    Structure first, line by line; inline markup afterwards over the whole text, because
    emphasis spans line breaks and a per-line pass silently leaves those behind.
    """
    out = []
    for line in md.split("\n"):
        if line.startswith("|"):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
                continue                                   # table rule
            cells = [c for c in cells if c]
            line = " - ".join(cells) if len(cells) > 1 else "".join(cells)
            line = "  " + line if line else line
        elif line.startswith("#"):
            line = line.lstrip("#").strip().upper()
        elif line.startswith(">"):
            line = line.lstrip(">").strip()
        elif re.fullmatch(r"-{3,}", line.strip()):
            line = ""
        out.append(line.rstrip())

    text = "\n".join(out)

    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", text)        # links
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text, flags=re.S)             # bold, across lines
    text = re.sub(r"\*(?!\*)([^*]+?)\*(?!\*)", r"\1", text, flags=re.S)  # italics, across lines
    for a, b in (("`", ""), ("\u2605", ""), ("\u2705", ""), ("\u2014", "\u2014"),
                 ("\u2013", "-"), ("\u2026", "..."), ("\u2192", "->"),
                 ("\u00a0", " "), ("\u2019", "'"), ("\u201c", '"'), ("\u201d", '"')):
        text = text.replace(a, b)
    text = re.sub(r"[ \t]+\n", "\n", text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def main() -> None:
    body = (
        narrative()
        + "\n\n"
        + "=" * 78
        + "\nPRE-EXISTING WORK DISCLOSURE - reproduced in full, as the rules require\n"
        + "=" * 78
        + "\n\n"
        + plain(DISCLOSURE.read_text())
        + "\n"
    )
    OUT.write_text(body)
    print(f"wrote {OUT.relative_to(HERE.parent.parent)}")
    print(f"  {len(body):,} characters, {body.count(chr(10)) + 1:,} lines")
    for bad in ("**", "`", "~~~", "|---"):
        if bad in body:
            print(f"  WARNING: {bad!r} survived into the output")


if __name__ == "__main__":
    main()
