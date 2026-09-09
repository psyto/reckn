#!/usr/bin/env bash
# The release gate. It does NOT publish; it decides whether publishing would be honest.
#
# This exists because the alternative was a `prepare` lifecycle script. That fixed the
# symptom -- `npm pack` from a clean tree shipped four files and no code -- by running our
# build on whoever installed the package. An install-time hook in a package whose whole claim
# is "no one can decide your payout but a proof" is the wrong shape: it is arbitrary code
# execution on the consumer, from us, at install. So there are no lifecycle scripts, and the
# property they were protecting is asserted HERE and in test/packaging.test.ts instead.
#
#   bash release-gate.sh
#
# Every check prints what it MEASURED, not that it passed.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
fail=0
say () { printf '%s\n' "$*"; }
bad () { printf 'FAIL  %s\n' "$*"; fail=1; }

say "── 1. no lifecycle scripts ─────────────────────────────────────────────"
# npm runs these without being asked, on the consumer's machine for git installs.
LIFECYCLE='preinstall install postinstall prepare prepublish prepublishOnly prepack postpack preuninstall uninstall postuninstall'
found=""
for h in $LIFECYCLE; do
  node -e "process.exit(require('./package.json').scripts?.['$h']?0:1)" && found="$found $h"
done
if [[ -n "$found" ]]; then bad "package.json declares lifecycle script(s):$found"; else say "  none declared"; fi

say "── 2. a build that provably matches the sources ────────────────────────"
# The first version of this gate ran the tests (which build) and then packed, so step 3 was
# inspecting a dist/ that step 2 had just created. It reported 17 files for a tree that had
# never compiled -- the gate manufactured the condition it was checking. Building explicitly
# from scratch here means the packed bytes correspond to the sources in front of us, and a
# stale dist/ left over from an older commit cannot be published as if it were current.
rm -rf dist
npm run build --silent >/dev/null 2>&1 || bad "the sources do not compile"
say "  rebuilt dist/ from src/ ($(find dist -name '*.js' 2>/dev/null | wc -l | tr -d ' ') modules)"

say "── 3. the tests ────────────────────────────────────────────────────────"
out=$(npm test 2>&1) || { bad "npm test exited non-zero"; }
counts=$(printf '%s\n' "$out" | awk '/^. (tests|pass|fail)/{printf "%s=%s ", $2, $NF}')
say "  $counts"
printf '%s\n' "$out" | awk '/^. fail/{ if ($NF+0 != 0) exit 1 }' || bad "tests failed"

say "── 4. what the tarball would contain ───────────────────────────────────"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
npm pack --dry-run --json > "$tmp/pack.json" 2>"$tmp/pack.err" || { bad "npm pack failed"; cat "$tmp/pack.err"; }
node - "$tmp/pack.json" <<'NODE' || fail=1
const fs = require("fs");
const pack = JSON.parse(fs.readFileSync(process.argv[2], "utf8"))[0] ?? {};
const files = (pack.files ?? []).map((f) => f.path);
const pkg = JSON.parse(fs.readFileSync("./package.json", "utf8"));
console.log(`  ${files.length} files, ${pack.size} bytes packed`);
let bad = 0;
// Everything the manifest points at must be IN THE TARBALL -- not merely on this disk.
const promised = [pkg.main, pkg.types, ...Object.values(pkg.bin ?? {}),
  ...Object.values(pkg.exports?.["."] ?? {})].filter(Boolean).map((p) => p.replace(/^\.\//, ""));
for (const p of new Set(promised)) {
  if (!files.includes(p)) { console.log(`FAIL  manifest points at ${p}, which is NOT in the tarball`); bad = 1; }
}
if (!files.includes("README.md")) { console.log("FAIL  no README.md in the tarball"); bad = 1; }
if (!files.some((f) => f.startsWith("dist/"))) { console.log("FAIL  no dist/ in the tarball"); bad = 1; }
if (!/^\d+\.\d+\.\d+$/.test(pkg.version)) { console.log(`FAIL  version ${pkg.version} is not a pinned release`); bad = 1; }
if (!pkg.name.startsWith("@")) { console.log(`FAIL  ${pkg.name} is not scoped`); bad = 1; }
console.log("  dependencies: " + Object.entries(pkg.dependencies ?? {}).map(([k, v]) => `${k}@${v}`).join(", "));
process.exit(bad);
NODE

say "── 5. the tarball, installed and actually run ──────────────────────────"
# Inspecting the file LIST is not the same as installing it. Measured 2026-09-09: the list
# looked perfect while `reckn profiles` printed INVALID for all three shipped profiles to
# anyone who installed the package, because evidence paths are repository paths and resolve to
# nothing from node_modules. Nothing that reads the manifest could have seen that. So this
# installs the tarball into an empty project and runs the CLI as a consumer would.
consumer="$tmp/consumer"; mkdir -p "$consumer"
printf '{ "name": "consumer", "private": true, "type": "module", "version": "1.0.0" }\n' > "$consumer/package.json"
tgz=$(npm pack --pack-destination "$tmp" 2>/dev/null | tail -1)
if [[ -z "$tgz" || ! -f "$tmp/$tgz" ]]; then bad "npm pack produced no tarball"; else
  if ( cd "$consumer" && npm install --silent "$tmp/$tgz" >/dev/null 2>&1 ); then
    out=$( cd "$consumer" && npx reckn profiles 2>&1 ); rc=$?
    n_ok=$(printf '%s\n' "$out" | grep -c '^ok ' || true)
    n_bad=$(printf '%s\n' "$out" | grep -c '^INVALID' || true)
    say "  installed and ran: $n_ok profile(s) ok, $n_bad reported INVALID, exit $rc"
    [[ $rc -eq 0 ]] || bad "the CLI a consumer installs exits $rc on \`reckn profiles\`"
    [[ $n_bad -eq 0 ]] || bad "$n_bad shipped profile(s) report INVALID from an installed package"
    [[ $n_ok -gt 0 ]] || bad "no profile was readable from the installed package"
    ( cd "$consumer" && node -e "import('@reckn/partner-kit').then(m=>{
        const need=['createDeal','sellerPreflight','submitProof','verifySettlement','buildTerms','evmDealBinding'];
        const miss=need.filter(x=>!(x in m)); if (miss.length) { console.log('FAIL  missing from the installed package: '+miss.join(' ')); process.exit(1); }
        console.log('  importable: '+Object.keys(m).length+' exports, all entry points present');
      }).catch(e=>{console.log('FAIL  import failed: '+e.message);process.exit(1)})" ) || fail=1
  else bad "the tarball does not install into an empty project"; fi
fi

say "── 6. publishing itself ────────────────────────────────────────────────"
say "  NOTE: with no lifecycle scripts, \`npm pack\` on its own does NOT build. A hand-run"
say "  \`npm publish\` from a tree that has not been built ships a tarball with no dist/ --"
say "  measured, that is 4 files and no code. That is not a defect to fix with an install-time"
say "  hook on the consumer; it is the reason publishing may only happen from CI, which builds"
say "  first. This gate rebuilds before it looks, so what it reports is what a CI run ships."
say "  NOT DONE HERE, and not by hand. Publishing must run from GitHub Actions with"
say "  OIDC trusted publishing and --provenance, on a tagged commit, with 2FA on the"
say "  npm account and a staged (dist-tag) release before latest. Until that workflow"
say "  exists and has run, this package is NOT on the registry and no document may"
say "  tell a reader to npm install or npx it."
say "  A consumer verifies what they received with:  npm audit signatures"
say "  and the provenance panel on the package page. npm must not be the only path:"
say "  the Git tag and vendored source stay supported."

[[ $fail -eq 0 ]] && say "" && say "release gate: PASS (this is a readiness check, not a publish)" || { say ""; say "release gate: FAIL"; }
exit $fail
