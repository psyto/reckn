#!/usr/bin/env python3
"""Write textarea-safe copies of the short description and “How it's made” fields.

The ETHGlobal form is a plain-text textarea. Markdown's wrapped source lines and any leading
space become visible formatting, so this renderer joins each prose paragraph into one line and
preserves only blank lines between paragraphs.
"""

import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
FORM = HERE / "SUBMISSION-FORM.md"
FIELDS = {
    "short-description": ("## 3. Short description", "## 4. Description", "SHORT-DESCRIPTION.txt"),
    "how-its-made": ("## 5. How it's made", "## 6. Partner prize", "HOW-ITS-MADE.txt"),
}


def copy_block(text: str, start: str, end: str) -> str:
    section = text[text.index(start): text.index(end)]
    blocks = re.findall(r"~~~text\n(.*?)~~~", section, re.S)
    if len(blocks) != 1:
        sys.exit(f"expected exactly one copy block in {start!r}, found {len(blocks)}")
    return blocks[0].strip()


def textarea_text(block: str) -> str:
    paragraphs = []
    current = []
    for raw in block.splitlines():
        line = raw.strip()
        if line:
            current.append(line)
        elif current:
            paragraphs.append(" ".join(current))
            current = []
    if current:
        paragraphs.append(" ".join(current))
    return "\n\n".join(paragraphs) + "\n"


def main() -> None:
    selected = sys.argv[1:] or list(FIELDS)
    text = FORM.read_text()
    for name in selected:
        if name not in FIELDS:
            sys.exit(f"unknown field: {name}; choose from {', '.join(FIELDS)}")
        start, end, filename = FIELDS[name]
        rendered = textarea_text(copy_block(text, start, end))
        target = HERE / filename
        target.write_text(rendered)
        print(f"wrote {target.relative_to(HERE.parent.parent)} ({len(rendered.strip()):,} characters)")


if __name__ == "__main__":
    main()
