#!/usr/bin/env bash
# AC-11 — the documents moved in the same commit as the claim.
#
# Four replacements present, four retired sentences absent, the authority sentence
# PRESERVED (not replaced), and the anchoring caveat adjacent to the claim it
# qualifies — because a caveat in a footnote is a caveat nobody reads.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
docs=("README.md" "zk-verdict/README.md" "AGENTS.md" "CLAUDE.md")
for d in "${docs[@]}"; do [[ -f "$root/$d" ]] || { echo "missing $d"; exit 2; }; done

fail=0
note() { printf '  %s\n' "$*"; fail=1; }
present=0
absent=0

# §11(1)…§11(4): one replacement per document.
while IFS=$'\t' read -r f marker; do
  [[ -n "$f" ]] || continue
  if grep -qF -- "$marker" "$root/$f"; then
    present=$((present + 1))
  else
    note "MISSING   $f: $marker"
  fi
done <<'MARKERS'
zk-verdict/README.md	Honest scope of cross-VM settlement
README.md	settled by a proof about a Solana-shaped state the deal named
AGENTS.md	入口の集合を閉じる
CLAUDE.md	funder が program を選び、その program が検査した proof が payout を選ぶ
MARKERS

# The four sentences 009 retires. The last is a negative on 009's OWN prose: round 1
# of the spec called SP1 verification "defence in depth" and §11(4) would have shipped
# that inversion into the file the central claim lives in.
retired=(
  'fund(dealId, seller, token, amount, dealBinding)'
  'task 009 closes it'
  'there is no path to a payout that skips proof verification'
)
for r in "${retired[@]}"; do
  hits=$( (cd "$root" && grep -lF -- "$r" "${docs[@]}" 2>/dev/null || true) | tr '\n' ' ')
  if [[ -z "$hits" ]]; then absent=$((absent + 1)); else note "STILL PRESENT  '$r' in $hits"; fi
done
dd=$(cd "$root" && { grep -lF -- 'defence in depth' CLAUDE.md zk-verdict/README.md 2>/dev/null || true
                     grep -lF -- 'defense in depth' CLAUDE.md zk-verdict/README.md 2>/dev/null || true; } | tr '\n' ' ')
if [[ -z "$dd" ]]; then absent=$((absent + 1)); else note "STILL PRESENT  'defen[cs]e in depth' in $dd"; fi

# A PRESERVATION, not a replacement: this sentence is what barrier B-2 is, it was
# already in the file, and 009's edit must not remove or weaken it.
preserved=0
if grep -qF -- '決済権限は「proof が検証される」ことから来る' "$root/CLAUDE.md"; then
  preserved=1
else
  note "REMOVED   CLAUDE.md no longer says 決済権限は「proof が検証される」ことから来る"
fi

# The caveat travels with the claim: the cross-VM paragraph and the anchoring
# paragraph must be within 25 lines of each other, and the limit must appear
# somewhere else too, so the adjacency is not the only place it lives.
adjacent=0
claim_line=$( (grep -nF 'One escrow, two virtual machines' "$root/zk-verdict/README.md" || true) | head -1 | cut -d: -f1)
anchor_line=$( (grep -nF 'Anchoring is not what this closes' "$root/zk-verdict/README.md" || true) | head -1 | cut -d: -f1)
elsewhere=$( (cd "$root" && grep -lF 'not about anchoring' README.md zk-verdict/README.md 2>/dev/null || true) | wc -l | tr -d ' ')
if [[ -z "$claim_line" || -z "$anchor_line" ]]; then
  note "the cross-VM claim or the anchoring limit is missing from zk-verdict/README.md"
elif [[ $((anchor_line - claim_line)) -gt 25 || $((anchor_line - claim_line)) -lt -25 ]]; then
  note "the anchoring limit is $((anchor_line - claim_line)) lines from the claim; 25 is the limit"
elif [[ "$elsewhere" == "0" ]]; then
  note "the anchoring limit appears only next to the claim and nowhere else"
else
  adjacent=1
fi

witness=$( (cd "$root" && cat "${docs[@]}") | shasum -a 256 | cut -c1-16)
echo "docs: $present/4 replacements present, $absent/4 retired sentences absent, $adjacent/1 anchoring sentence adjacent, $preserved/1 authority sentence preserved; witness=$witness"
[[ $fail -eq 0 ]] || exit 1
