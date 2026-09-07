#!/usr/bin/env python3
"""Generate SUBMISSION-FORM.md §6b from DISCLOSURE.md, so the two cannot disagree.

The rules require the disclosure to be reproduced IN FULL in the submission description.
A human retyping a 100-line document into a form is a transcription, and this repository
spent 2026-09-06 learning what transcriptions do: two of four live transaction hashes
were copied wrong — right length, right prefix, linking to nothing.

So §6b is not written. It is rendered from `DISCLOSURE.md` (markdown stripped, since the
form field is plain text), verbatim. It used to apply two corrections on the way through, because two sentences in
the committed file had stopped being true; on 2026-09-07 the founder applied both to
`DISCLOSURE.md` itself, so there is nothing left to diverge and this script only guards
against the corrections being lost again.

  python3 docs/ethonline-2026/build-form.py      # rewrites the §6b block in place
"""
import pathlib, re, sys

here = pathlib.Path(__file__).resolve().parent
disc = (here / "DISCLOSURE.md").read_text()
form_path = here / "SUBMISSION-FORM.md"
form = form_path.read_text()

# 2026-09-07: the two divergences are GONE. The founder applied both amendments to
# DISCLOSURE.md itself, so this script no longer edits anything — §6b is now a faithful
# rendering, and the form and the disclosure say the same words.
#
# What is left is a guard in the other direction. An empty EDITS list would silently
# accept a disclosure that regressed to the old wording, so the corrected sentences are
# asserted PRESENT. A positive check is used rather than "the old phrases are absent",
# because the old phrases are legitimately quoted in the Amendments table — a naive
# absence check would fail on the document's own honesty.
REQUIRED = [
    ("Sponsor integration: Arc.",
     "§3 item 5 named World AgentKit, which was never built, and buried Arc in a "
     "conditional parenthetical."),
    ("would be evidence of nothing",
     "§3 item 3 promised persuading the LLM judge; 004's claim is judge-independent."),
    ("## 0. Amendments",
     "the disclosure must carry its own change history, since it is reproduced in full "
     "in the submission description and a reader is entitled to see where it moved."),
]

body = disc
for probe, why in REQUIRED:
    if probe not in body:
        sys.exit(f"build-form: DISCLOSURE.md has regressed — {probe!r} is missing.\n"
                 f"  {why}\n"
                 f"  Refusing to render a form field from a disclosure that lost a "
                 f"correction it already made.")

# markdown -> plain text, losing nothing: headings keep their words, emphasis and code
# ticks go, link text is kept over the URL, the italic send-instruction and the rule are
# dropped because they are instructions to us and not part of the disclosure.
body = re.sub(r"^\*Send to the ETHGlobal team.*?\n\n", "", body, flags=re.S | re.M)
body = body.replace("\n---\n", "\n")
body = re.sub(r"^# (.+)$", lambda m: m.group(1), body, flags=re.M)
body = re.sub(r"^## (.+)$", lambda m: m.group(1).upper(), body, flags=re.M)
body = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1 (\2)", body)
body = body.replace("**", "").replace("*", "").replace("`", "")
body = re.sub(r"\n{3,}", "\n\n", body).strip()

start, end = "<!--DISCLOSURE:BEGIN-->", "<!--DISCLOSURE:END-->"
if start not in form or end not in form:
    sys.exit("build-form: the markers are missing from SUBMISSION-FORM.md")
head, rest = form.split(start, 1)
_, tail = rest.split(end, 1)
form = f"{head}{start}\n```\n{body}\n```\n{end}{tail}"
form_path.write_text(form)
print(f"SUBMISSION-FORM.md §6b rendered from DISCLOSURE.md verbatim "
      f"({len(body.splitlines())} lines, 0 divergences, {len(REQUIRED)} guards held)")
