#!/usr/bin/env bash
# AC-7 — the escrow's shape is closed.
#
# Ten clauses over `RecknZkEscrow.sol`. Every count is a literal of
# docs/specs/009-cross-vm-settlement.md §7, transcribed from §3.3 — not a value this
# script derives from the file it is checking. That matters: when a pinned count
# disagrees with the file, the cheapest route to green is to NARROW THE OBSERVER
# until it agrees, and a clause whose numbers are wrong is worse than no clause,
# because it converts a gate into an instruction to blind it.
#
# This script takes no argument, reads no environment variable, and does not invoke
# `forge`, so the selftest can run it against a sandbox copy with no build.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
escrow="$root/zk-verdict/contracts/src/RecknZkEscrow.sol"
verifier="$root/zk-verdict/contracts/src/RecknVerdictVerifier.sol"
for f in "$escrow" "$verifier"; do [[ -f "$f" ]] || { echo "missing $f"; exit 2; }; done

fail=0
note() { printf '  %s\n' "$*"; fail=1; }
count() { printf '%s\n' "$2" | grep -ow "$1" | wc -l | tr -d ' '; }

# The region: from the `contract RecknZkEscrow` line onward, comments stripped with
# the idiom no-keys.sh already uses.
region=$(awk '/^contract RecknZkEscrow/{f=1} f' "$escrow" | sed -e 's://.*::' -e 's:/\*.*\*/::')
whole=$(sed -e 's://.*::' -e 's:/\*.*\*/::' "$escrow")
[[ -n "$region" ]] || { echo "could not isolate the contract region"; exit 2; }

# 7a — the region is literal, so the line-based, quote-blind stripper is exact.
blk_open=$(grep -c -F '/*' "$escrow" || true)
blk_close=$(grep -c -F '*/' "$escrow" || true)
quoted=$(printf '%s\n' "$region" | grep -c '["'"'"']' || true)
[[ "$blk_open" == "0" && "$blk_close" == "0" ]] || note "7a: block comments present ($blk_open, $blk_close)"
[[ "$quoted" == "0" ]] || note "7a: $quoted quoted line(s) — a string can hide a declaration from the stripper"

# 7b — no deployment-time configuration. Fails together with no-keys.sh check 4b.
ctor=$( (printf '%s\n' "$region" | grep -ow constructor || true) | wc -l | tr -d ' ')
immut=$( (printf '%s\n' "$region" | grep -ow immutable || true) | wc -l | tr -d ' ')
[[ "$ctor" == "0" ]] || note "7b: $ctor constructor"
[[ "$immut" == "0" ]] || note "7b: $immut immutable"

# 7c — one storage variable, and it is the deals mapping.
mappings=$( (printf '%s\n' "$region" | grep -ow mapping || true) | wc -l | tr -d ' ')
mapline=$(printf '%s\n' "$region" | grep -F 'mapping' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]][[:space:]]*/ /g' | head -1)
[[ "$mappings" == "1" ]] || note "7c: $mappings mapping declarations; exactly 1 permitted"
[[ "$mapline" == "mapping(bytes32 => Deal) public deals;" ]] || note "7c: the mapping line is '$mapline'"

# 7d — the verdict record's read set, in both directions. The member names are READ
# from the verifier's struct at run time, never written here, so a member a sibling
# task adds is covered on the commit that adds it.
read_set=$(python3 - "$verifier" "$escrow" <<'PY'
import re, sys
verifier, escrow = sys.argv[1], sys.argv[2]
src = open(verifier).read()
block = re.search(r'struct VerdictPublicValues\s*\{(.*?)\}', src, re.S).group(1)
members = re.findall(r'^\s*[A-Za-z_][A-Za-z0-9_\[\]]*\s+([A-Za-z_][A-Za-z0-9_]*)\s*;', block, re.M)
body = open(escrow).read()
body = re.sub(r'//.*', '', body)
i = body.index('contract RecknZkEscrow')
body = body[i:]
want = {'dealBinding': 1, 'outcome': 3, 'traceHash': 1}
read = 0
bad = []
for m in members:
    n = len(re.findall(r'\bv\.' + m + r'\b', body))
    if m in want:
        if n != want[m]:
            bad.append(f"v.{m} x{n}, expected x{want[m]}")
        else:
            read += n
    elif n != 0:
        bad.append(f"v.{m} x{n}, expected x0")
print(len(members), read, len(want), len(members) - len(want), ";".join(bad))
PY
)
set -- $read_set
n_members=$1; n_access=$2; n_read=$3; n_unread=$4; d_bad=${5:-}
[[ -z "$d_bad" ]] || note "7d: $d_bad"
[[ "$n_access" == "5" ]] || note "7d: $n_access accesses to the read members, 5 expected"

# 7e — the dispatch site is singular, and it goes through the deal's own verifier.
# R-8: this does not constrain what d.verifier resolves to at run time. AC-3 test 2
# does, behaviourally. The two are a pair.
vtok=$( (printf '%s\n' "$region" | grep -ow RecknVerdictVerifier || true) | wc -l | tr -d ' ')
vline=$(printf '%s\n' "$region" | grep -F 'RecknVerdictVerifier' | head -1)
[[ "$vtok" == "1" ]] || note "7e: $vtok RecknVerdictVerifier tokens; exactly 1 permitted"
printf '%s\n' "$vline" | grep -qF 'd.verifier' || note "7e: the dispatch does not go through d.verifier"

# 7f — assignment targets AND sources are closed. The left-hand side carries its
# declarator: `Deal storage d` and `Deal memory d` differ only there, and with
# `memory` the state write lands on a copy and the same proof settles twice.
shape=$(python3 - <<'PY' "$escrow"
import re, sys
src = open(sys.argv[1]).read()
src = re.sub(r'//.*', '', src)
src = src[src.index('contract RecknZkEscrow'):]
flat = re.sub(r'\s+', ' ', src)
pieces = [p.strip() for p in re.split(r'[;{}]', flat) if p.strip()]
want_lhs = {
 'uint8 public constant REPRODUCED': 1,
 'uint8 public constant FAILED': 1,
 'bytes32 public constant EMPTY_CODEHASH': 1,
 'deals[dealId]': 1,
 'Deal storage d': 1,
 'VerdictPublicValues memory v': 1,
 'd.state': 1,
 'to': 2,
}
want_rhs = {
 'Deal storage d': ['deals[dealId]'],
 'VerdictPublicValues memory v': ['RecknVerdictVerifier(d.verifier).verifyVerdict(publicValues, proofBytes)'],
 'to': ['d.seller', 'd.buyer'],
}
got = {}
rhs = {}
n = 0
for st in pieces:
    i = 0
    while i < len(st):
        if st[i] == '=':
            p = st[i-1] if i else 'X'
            q = st[i+1] if i + 1 < len(st) else 'X'
            if p in '=!<>' or q in ('=', '>'):
                i += 2
                continue
            lhs = st[:i].strip()
            r = st[i+1:].strip()
            got[lhs] = got.get(lhs, 0) + 1
            rhs.setdefault(lhs, []).append(r)
            n += 1
            break
        i += 1
bad = []
if got != want_lhs:
    for k in sorted(set(got) | set(want_lhs)):
        if got.get(k, 0) != want_lhs.get(k, 0):
            bad.append(f"lhs {k!r} x{got.get(k,0)} expected x{want_lhs.get(k,0)}")
for k, v in want_rhs.items():
    if rhs.get(k) != v:
        bad.append(f"rhs of {k!r} is {rhs.get(k)} expected {v}")
print(n, len(got), "|", "; ".join(bad))
PY
)
n_assign=$(printf '%s' "$shape" | awk '{print $1}')
n_targets=$(printf '%s' "$shape" | awk '{print $2}')
f_bad=$(printf '%s' "$shape" | sed 's/^[^|]*| *//')
[[ -z "$f_bad" ]] || note "7f: $f_bad"
[[ "$n_assign" == "9" && "$n_targets" == "8" ]] || note "7f: $n_assign assignments over $n_targets targets; 9 over 8 expected"

# 7h — the callable surface is closed as a property over the grammar. K is the
# complete set of 0.8.x keywords introducing code reachable AFTER deployment at
# member level; `constructor` is deliberately not in it (7b's).
sum=0
for kw in function fallback receive modifier; do
  n=$( (printf '%s\n' "$region" | grep -ow "$kw" || true) | wc -l | tr -d ' ')
  sum=$((sum + n))
  [[ "$kw" == "function" || "$n" == "0" ]] || note "7h: $n '$kw'"
done
fns=$(printf '%s\n' "$region" | grep -oE '\bfunction +[A-Za-z_][A-Za-z0-9_]*' | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//')
[[ "$fns" == "fund settleWithProof" ]] || note "7h: functions are '$fns', not 'fund settleWithProof'"
n_fn=$( (printf '%s\n' "$region" | grep -ow function || true) | wc -l | tr -d ' ')
[[ "$n_fn" == "2" ]] || note "7h: $n_fn function declarations"

# 7i — the lexical reading is well-defined. `using` is counted over the WHOLE file:
# a `using ... for` above the contract line makes member-call resolution non-local.
asm=$( (printf '%s\n' "$region" | grep -ow assembly || true) | wc -l | tr -d ' ')
usings=$( (printf '%s\n' "$whole" | grep -ow using || true) | wc -l | tr -d ' ')
[[ "$asm" == "0" ]] || note "7i: $asm assembly blocks — a second language this script cannot read"
[[ "$usings" == "0" ]] || note "7i: $usings using directives — member-call resolution is no longer local"

# 7j — the region is the whole of the deployed code. An INHERITED member is declared
# ABOVE the contract line, so 7a-7i would not see it. Measured before this clause
# existed: a base contract carrying a draining fallback compiled and took a funded
# deal with every other clause green.
inherit=$(sed -n 's/.*contract RecknZkEscrow\(.*\){.*/\1/p' "$escrow" | tr -d ' \t')
contracts=$( (grep -ow contract "$escrow" || true) | wc -l | tr -d ' ')
[[ -z "$inherit" ]] || note "7j: RecknZkEscrow inherits ($inherit)"
[[ "$contracts" == "1" ]] || note "7j: $contracts contract declarations in the file"

witness=$(cat "$escrow" "$verifier" | shasum -a 256 | cut -c1-16)
echo "escrow-shape: $ctor constructor, $immut immutable, $mappings mapping, verdict members $n_read/$n_read read ($n_access accesses) and $n_unread/$n_unread unread, $n_assign assignments over $n_targets targets, function $n_fn ($fns) other entry keywords $((sum - n_fn)) sum $sum, $asm assembly $usings using, $contracts contract $([[ -z "$inherit" ]] && echo 0 || echo 1) inherited; witness=$witness"
[[ $fail -eq 0 ]] || exit 1
