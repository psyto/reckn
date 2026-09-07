#!/usr/bin/env python3
"""Generate SUBMISSION-FORM.md §6b from DISCLOSURE.md, so the two cannot disagree.

The rules require the disclosure to be reproduced IN FULL in the submission description.
A human retyping a 100-line document into a form is a transcription, and this repository
spent 2026-09-06 learning what transcriptions do: two of four live transaction hashes
were copied wrong — right length, right prefix, linking to nothing.

So §6b is not written. It is rendered from `DISCLOSURE.md` (markdown stripped, since the
form field is plain text), with exactly the edits listed in EDITS applied and each one
marked, because two sentences in the committed file stopped being true after it was
written and `DISCLOSURE.md` is a founder document this script does not touch.

  python3 docs/ethonline-2026/build-form.py      # rewrites the §6b block in place
"""
import pathlib, re, sys

here = pathlib.Path(__file__).resolve().parent
disc = (here / "DISCLOSURE.md").read_text()
form_path = here / "SUBMISSION-FORM.md"
form = form_path.read_text()

# (find, replace, why) — every divergence from the committed disclosure, declared.
EDITS = [
    ("3. **Live adversarial dispute input.** Open the seller's delivery claim to free-form input\n"
     "   so any observer can attempt to persuade the LLM judge, and watch re-execution disagree.",
     "3. [UPDATED] Live adversarial dispute input. Open the seller's delivery claim to free-form\n"
     "   input, so any observer can write whatever they like about what was delivered — and watch\n"
     "   it change nothing. The claim is that PROSE DOES NOT MOVE RE-EXECUTION, and it is stated\n"
     "   without reference to any judge, because a judge we wrote ourselves being \"persuaded\"\n"
     "   would be evidence of nothing.",
     "004's specification made the headline claim judge-independent by founder ruling, and "
     "forbids citing a self-written stub judge as evidence of persuasion. The disclosure "
     "promised the thing the specification removed."),
    ("5. **Sponsor integrations (new):** World AgentKit gating who may open a dispute.\n"
     "   *(Integrations against Arc/USDC and Hedera/x402 were listed at application time; the\n"
     "   full prize list was not yet published, and they will be attempted only if those\n"
     "   sponsors are confirmed for this event.)*",
     "5. [UPDATED] Sponsor integration: Arc. Reckn's keyless escrow settles in Circle's USDC on\n"
     "   Arc with no change to the contract — a deal names its payment token at funding, so a\n"
     "   chain whose money is USDC needs evidence rather than adaptation. Built during the event\n"
     "   and deployed to Arc testnet, where four settlements moved real testnet USDC: a proof\n"
     "   released the seller, a proof of a wrong execution refunded the buyer, and two of the\n"
     "   four were decided by proofs about work performed on Solana — one escrow, two virtual\n"
     "   machines, no bridge and no resolver in the path that chose the payout. A fifth deal is\n"
     "   frozen at 1.00 USDC because Circle's USDC blacklists its recipient; it is refundable by\n"
     "   the keyless deadline and by nothing else, and it is recorded rather than hidden.\n"
     "   (At application time Arc and Hedera were both listed as conditional, because the prize\n"
     "   list was not yet published. Arc is the only sponsor integration attempted; Hedera and\n"
     "   World AgentKit were dropped by ruling on 2026-09-06.)",
     "World AgentKit was never implemented and is out of scope by ruling; Arc was built, "
     "deployed and settled four times. The disclosure named the thing that does not exist "
     "and buried the thing that does in a conditional parenthetical."),
]

body = disc
for find, repl, _ in EDITS:
    if body.count(find) != 1:
        sys.exit(f"build-form: this passage is not in DISCLOSURE.md exactly once — it was "
                 f"edited or already applied:\n---\n{find[:120]}…")
    body = body.replace(find, repl, 1)

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
print(f"SUBMISSION-FORM.md §6b rendered from DISCLOSURE.md "
      f"({len(body.splitlines())} lines, {len(EDITS)} declared edits)")
