#!/usr/bin/env bash
# No document may INSTRUCT a reader to run a command that does not resolve.
#
# `npx reckn` and `npm install @reckn/partner-kit` were written into the onboarding steps, the
# package README and the deck while both names 404 on the npm registry. A reader following
# them reaches the network and gets E404. That is worse than an omission: it is a step that
# looks tested.
#
# This does NOT keep a list of forbidden strings. It ASKS THE REGISTRY whether each name
# resolves, and only bans the ones that do not -- so the day the package is genuinely
# published, this check stops objecting on its own, with nothing to remember to edit.
#
# Instruction vs. prose is decided STRUCTURALLY, not by wording: inside a fenced code block
# (or anywhere in an HTML slide, which has no fences) it is an instruction. Outside, it is
# prose, and prose is allowed -- and required -- to say that the command does not work.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
NAMES=("reckn" "@reckn/partner-kit")
fail=0

declare -a UNRESOLVED=()
for n in "${NAMES[@]}"; do
  if npm view "$n" version >/dev/null 2>&1; then
    echo "resolves    $n is on the npm registry — instructions using it are allowed"
  else
    echo "UNRESOLVED  $n 404s on the npm registry"
    UNRESOLVED+=("$n")
  fi
done
if [[ ${#UNRESOLVED[@]} -eq 0 ]]; then
  echo; echo "PASS: every name a document tells a reader to run is published."
  exit 0
fi

echo
files=$(git ls-files '*.md' '*.html' | grep -v node_modules)
for f in $files; do
  python3 - "$f" "${UNRESOLVED[@]}" <<'PY'
import re, sys
path, names = sys.argv[1], sys.argv[2:]
text = open(path, encoding="utf-8", errors="replace").read().splitlines()
html = path.endswith(".html")
infence = False
bad = []
for i, line in enumerate(text, 1):
    if not html and re.match(r"^\s*```", line):
        infence = not infence
        continue
    # An instruction is one INSIDE a code fence, or anywhere in a slide deck.
    if not (infence or html):
        continue
    for n in names:
        if re.search(r"npx\s+" + re.escape(n) + r"\b", line) or \
           re.search(r"npm\s+(install|i|add)\s+[^\n]*" + re.escape(n) + r"\b", line):
            bad.append((i, n, line.strip()[:100]))
for i, n, s in bad:
    print(f"FAIL  {path}:{i}  instructs `{n}`, which does not resolve")
    print(f"      {s}")
sys.exit(1 if bad else 0)
PY
  [[ $? -ne 0 ]] && fail=1
done

if [[ $fail -eq 0 ]]; then
  echo "PASS: no document instructs an unresolvable command."
  echo "      (prose explaining that these names do not resolve is untouched, and should stay)"
else
  echo
  echo "Use \`bash scripts/reckn ...\`, which resolves from anywhere in this repository."
fi
exit $fail
