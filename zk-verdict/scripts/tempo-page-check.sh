#!/usr/bin/env bash
# tempo-page-check — run docs/tempo.html's OWN JavaScript against the real chain and require
# that what it renders is true.
#
# WHY. On 2026-09-08 the page said "Nothing is deployed to Tempo" for several hours after the
# escrow was deployed and had settled twice. It was generated from the record, every constant
# in it was honest, and it was still telling a judge something false -- because section 5's
# text was static prose and prose does not notice that the world moved. A judge-facing page
# that misstates the state is worse than no page: it is wrong in the voice of evidence.
#
# The first version of section 5's replacement then rendered "nothing moved" for two
# settlements that plainly moved money, because a helper took an address from a fixed offset
# and a log topic is two characters longer than a decoded word. Reading the page would not
# have caught that. Running it did.
#
# So this does not lint the HTML and does not check for phrases. It executes the page's
# script -- the same code the visitor's browser runs -- against Tempo, with a stub DOM, and
# requires the section-5 status to come out green. If the deployment is gone, repriced,
# re-org'd, or the record drifts from the page, this goes red for the same reason the page
# would mislead.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
page="$root/docs/tempo.html"
rec="$root/zk-verdict/contracts/tempo.json"
command -v node >/dev/null || { echo "tempo-page-check: node is required to run the page's own script"; exit 2; }

# The page is generated. Regenerate first and fail if that changes it: a page edited by hand
# is a page that will drift from the record it claims to be generated from.
before=$(shasum -a 256 "$page" | cut -d' ' -f1)
python3 "$root/dashboard/live/generate-tempo.py" >/dev/null
after=$(shasum -a 256 "$page" | cut -d' ' -f1)
if [[ "$before" != "$after" ]]; then
  echo "tempo-page-check: docs/tempo.html was NOT what the generator produces -- it has been"
  echo "  hand-edited, or the record changed without regenerating. It is regenerated now;"
  echo "  review the diff and commit it."
  exit 1
fi

node - "$page" "$rec" <<'JS'
const fs = require("fs");
const [page, rec] = process.argv.slice(2);
const html = fs.readFileSync(page, "utf8");
const record = JSON.parse(fs.readFileSync(rec, "utf8"));
const script = html.split("<script>")[1].split("</script>")[0];

let bad = 0;
const fail = (m) => { console.log("  [FAIL] " + m); bad = 1; };
const ok = (m) => console.log("  [ok ] " + m);

// Every element the script writes to must exist. A put() to a missing id is silent.
const ids = new Set([...script.matchAll(/\$\("([^"]+)"\)|put\("([^"]+)"|set\("([^"]+)"/g)]
  .map((m) => m[1] || m[2] || m[3]));
const missing = [...ids].filter((id) => !html.includes(`id="${id}"`));
missing.length ? fail(`the script writes to ${missing.length} id(s) the page does not have: ${missing}`)
               : ok(`all ${ids.size} element ids the script writes to exist`);

// The page must carry the deployment the record carries -- neither ahead nor behind.
const dep = record.deployedByReckn || {};
if (dep.RecknZkEscrow) {
  html.includes(dep.RecknZkEscrow) ? ok(`the page names the deployed escrow ${dep.RecknZkEscrow}`)
                                   : fail("the record has a deployment the page does not name");
}

const out = {}, rows = [];
global.document = {
  createElement: () => ({ innerHTML: "", appendChild() {} }),
  getElementById: (id) => ({
    set className(v) { out[id + "@class"] = v; },
    set textContent(v) { out[id] = v; },
    style: {}, appendChild(n) { rows.push({ id, html: n.innerHTML }); },
  }),
};
eval(script.replace(/^const CFG = \{/m, "var CFG = {"));

setTimeout(() => {
  // Every section that reports a status must report a good one. Listed rather than
  // discovered, so a section that stops rendering its status is a failure and not a pass.
  for (const [id, what] of [["s-chain", "which chain this is"], ["s-pre", "the BN254 precompiles"],
                            ["s-bal", "the absent native balance"], ["s-tok", "the fee token"],
                            ["s-fee", "what paid for real receipts"],
                            ["s-settle", "the settlements"]]) {
    const cls = out[id + "@class"];
    if (cls === undefined) fail(`${what}: rendered no status at all`);
    else if (cls === "st ok") ok(`${what}: ${out[id.replace("s-", "t-")] || "ok"}`);
    else fail(`${what}: ${cls} -- ${out[id.replace("s-", "t-")] || "(no message)"}`);
  }
  const settled = rows.filter((r) => r.id === "rows-settle");
  if (dep.RecknZkEscrow && settled.length !== (dep.verified?.cases?.length ?? 0))
    fail(`the record has ${dep.verified?.cases?.length} deals, the page rendered ${settled.length}`);
  else if (dep.RecknZkEscrow) ok(`${settled.length} deal rows rendered, one per recorded case`);
  settled.forEach((r) => console.log("         " + r.html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim()));
  if (bad) { console.log("tempo-page-check: the page does not render the truth."); process.exit(1); }
  console.log("tempo-page-check: docs/tempo.html renders correctly against the live chain.");
}, 30000);
JS
