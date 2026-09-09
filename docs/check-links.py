#!/usr/bin/env python3
"""Every link in the documentation has to point at something that exists.

WHY THIS EXISTS. On 2026-09-09 the README was split: `Status` and `Repository layout` moved
into `docs/status.md` and `docs/layout.md`. Both files kept the link targets they had while
they lived at the repository root, so from inside `docs/` every one of them pointed at nothing
-- 27 dead links, in the two pages a reader is sent to when they want to know what is NOT done.
Three more links inside the README still said "below" and pointed at a section that had left
the file. Nothing turned red, because nothing was looking.

It checks two things and nothing else:

  * relative links resolve to a file that exists
  * `#anchors` into a Markdown file match a heading in that file

Nothing here checks whether a link points at the RIGHT thing -- only that it points at
something. A green run means no reader hits a 404; it does not mean the prose is correct.

    python3 docs/check-links.py          # exit 1 if anything is dead
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HEAD = re.compile(r"^#{1,6}\s+(.+?)\s*$", re.M)


def slug(text: str) -> str:
    """GitHub's heading -> anchor rule, close enough for our headings."""
    t = re.sub(r"`|\*|_", "", text.lower())
    t = re.sub(r"[^a-z0-9 \-]", "", t)
    return t.strip().replace(" ", "-")


def anchors(path: pathlib.Path) -> set[str]:
    return {slug(h) for h in HEAD.findall(path.read_text())}


def main() -> int:
    files = [ROOT / "README.md", *sorted(ROOT.glob("docs/**/*.md"))]
    dead: list[str] = []
    checked = 0

    for f in files:
        text = f.read_text()
        for m in LINK.finditer(text):
            target = m.group(1).strip()
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            checked += 1
            path_part, _, frag = target.partition("#")
            rel = f.relative_to(ROOT)

            if not path_part:                      # same-file anchor
                if frag and slug(frag) not in anchors(f):
                    dead.append(f"{rel}: #{frag} is not a heading in this file")
                continue

            dest = (f.parent / path_part).resolve()
            if not dest.exists():
                dead.append(f"{rel}: {path_part} does not exist")
                continue
            if frag and dest.suffix == ".md" and slug(frag) not in anchors(dest):
                dead.append(f"{rel}: {path_part}#{frag} is not a heading there")

    print(f"checked {checked} links across {len(files)} files")
    if dead:
        print(f"\n{len(dead)} dead:")
        for d in dead:
            print(f"  {d}")
        return 1
    print("all resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
