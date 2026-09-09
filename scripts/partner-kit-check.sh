#!/usr/bin/env bash
# Everything an adopter is told to run must actually run.
#
# On 2026-09-09 a commit made `specId` mandatory for EVM profiles, updated src/, profiles/ and
# the tests, and did not update examples/. The starter kept passing for a week of working-tree
# runs and was broken at HEAD the whole time: anyone cloning the repository got a profile that
# validateProfile rejects on the first call. Nothing caught it. Nothing could have: no gate in
# this repository runs the starter, and none runs the release gate either.
#
# That matters more now than it did, because the ETHOnline submission asserts "one command runs
# three paths". A claim nothing re-measures is a claim that decays.
#
# NOT NAMED ac0NN.sh, DELIBERATELY. `both-green.sh` discovers siblings by the closure
# ^ac[0-9]{3}\.sh$ among the files beside it, and its witness is a digest of that set. A new
# gate there would move AC-12's measurement, which is currently recorded in the submission.
# This lives in scripts/ under a name that closure cannot see, so it adds coverage without
# perturbing anything the submission cites.
#
#   bash scripts/partner-kit-check.sh
#
# Exit 0 = everything an adopter runs, runs. 1 = something is broken. 3 = COULD NOT VERIFY.
# Three codes and not two: a missing toolchain must never be reported as success. A gate that
# goes green because it could not look is the defect it exists to prevent.
set -uo pipefail
cd "$(dirname "$0")/.."
kit="packages/partner-kit"
fail=0; skipped=0
ok ()   { printf 'ok      %s\n' "$*"; }
bad ()  { printf 'FAIL    %s\n' "$*"; fail=1; }
skip () { printf 'SKIP    %s\n' "$*"; skipped=1; }

echo "── the package's own tests ─────────────────────────────────────────────"
out=$( (cd "$kit" && npm test) 2>&1 )
counts=$(printf '%s\n' "$out" | awk '/^. (tests|pass|fail)/{printf "%s=%s ", $2, $NF}')
if printf '%s\n' "$out" | awk '/^. fail/{exit ($NF+0==0)?0:1}'; then ok "$counts"; else bad "$counts"; fi

echo "── the first command a partner runs ────────────────────────────────────"
if command -v anvil >/dev/null 2>&1 && command -v forge >/dev/null 2>&1; then
  if out=$( (cd "$kit/examples/starter" && bash test.sh) 2>&1 ); then
    ok "starter: $(printf '%s\n' "$out" | grep -c '^  ok ') checks — release, refund, refusal"
  else
    bad "starter end to end"; printf '%s\n' "$out" | tail -12
  fi
else
  skip "starter — anvil and forge are required and one is missing. NOT a pass."
fi

echo "── what a consumer would receive ───────────────────────────────────────"
if out=$( (cd "$kit" && bash release-gate.sh) 2>&1 ); then
  ok "release gate: $(printf '%s\n' "$out" | grep -E 'installed and ran' | sed 's/^  //')"
else
  bad "release gate"; printf '%s\n' "$out" | grep -E 'FAIL|release gate:'
fi

echo "── the commands the docs tell a stranger to type ───────────────────────"
if bash scripts/no-unpublished-cli.sh >/dev/null 2>&1; then ok "no document instructs an unresolvable command"
else bad "a document instructs a command that does not resolve"; fi
if out=$(bash scripts/reckn profiles 2>&1) && ! printf '%s\n' "$out" | grep -q INVALID; then
  ok "scripts/reckn runs from the repository root: $(printf '%s\n' "$out" | grep -c '^ok ') profiles"
else
  bad "scripts/reckn profiles"; printf '%s\n' "$out" | head -4
fi

echo
if [[ $fail -ne 0 ]]; then echo "partner-kit-check: FAIL"; exit 1; fi
if [[ $skipped -ne 0 ]]; then
  echo "partner-kit-check: COULD NOT VERIFY — a required toolchain was absent, so this is"
  echo "                   not a pass. Re-run where anvil and forge exist before believing it."
  exit 3
fi
echo "partner-kit-check: everything an adopter is told to run, runs."
