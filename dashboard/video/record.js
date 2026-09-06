// Records the Arc demo to dashboard/media/reckn-arc-demo.mp4.
//
// It is a RECORDING, not an animation: every frame after the opening shot is a real
// page driving a real chain. The script starts `scripts/arc-demo.sh` itself, so the
// chain is fresh and the balances begin at zero; it clicks the same buttons a judge
// would; and the closing shot shows the actual stdout of `bash scripts/no-keys.sh`
// from this run, not a transcription of an older one.
//
// If a step does not produce the text it is supposed to produce, the recorder throws
// rather than shipping a video of something that did not happen.
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import { spawn, execFileSync } from "node:child_process";
import puppeteer from "puppeteer";
import { PuppeteerScreenRecorder } from "puppeteer-screen-recorder";

const dir = path.dirname(fileURLToPath(import.meta.url));
const repo = path.join(dir, "..", "..");
const out = path.join(repo, "dashboard", "media", "reckn-arc-demo.mp4");
const BASE = "http://127.0.0.1:8787";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- the chain ----
console.error("• starting the demo chain (anvil at Arc's chain id, deploy, USDC) …");
const demo = spawn("bash", [path.join(repo, "scripts", "arc-demo.sh")], {
  cwd: repo, stdio: "ignore", detached: true,
});
// The live page is plain static files; it needs a server only because a fetch from a
// file:// origin sends `Origin: null`, which a public RPC is entitled to refuse.
const LIVE = "http://127.0.0.1:8898";
const docs = spawn("python3", ["-m", "http.server", "8898", "--directory",
  path.join(repo, "docs")], { cwd: repo, stdio: "ignore", detached: true });
const stopDemo = () => {
  try { process.kill(-demo.pid, "SIGTERM"); } catch {}
  try { process.kill(-docs.pid, "SIGTERM"); } catch {}
};
process.on("exit", stopDemo);
process.on("SIGINT", () => { stopDemo(); process.exit(1); });

let up = false;
for (let i = 0; i < 240 && !up; i++) {
  try { up = (await fetch(BASE + "/api/state")).ok; } catch {}
  if (!up) await sleep(1000);
}
if (!up) throw new Error("the demo backend never answered on " + BASE);
const start = await (await fetch(BASE + "/api/state")).json();
if (start.escrow !== 0 || start.seller !== 0) {
  throw new Error("the chain is not fresh — refusing to record a run that started mid-story");
}
console.error("• chain up, chain id " + start.chainId);

// ---------------------------------------------------------------- the claim ----
// The last shot shows this run's bytes.
const noKeys = execFileSync("bash", [path.join(repo, "scripts", "no-keys.sh")], {
  cwd: repo, encoding: "utf8", maxBuffer: 4 * 1024 * 1024,
});
if (!/the claim holds/.test(noKeys)) {
  throw new Error("no-keys.sh did not print the claim — refusing to record");
}

// ---------------------------------------------------------------- recording ----
const browser = await puppeteer.launch({
  headless: "new",
  defaultViewport: { width: 1280, height: 800 },
  args: ["--window-size=1280,800", "--force-color-profile=srgb", "--hide-scrollbars"],
});
const page = await browser.newPage();
const rec = new PuppeteerScreenRecorder(page, { fps: 30, videoFrame: { width: 1280, height: 800 } });

async function card(text, ms = 2600) {
  await page.evaluate((t) => {
    const d = document.createElement("div");
    d.id = "__card";
    d.textContent = t;
    Object.assign(d.style, {
      position: "fixed", inset: "0", zIndex: "99999", display: "flex",
      alignItems: "center", justifyContent: "center", textAlign: "center",
      padding: "0 12%", background: "rgba(5,7,10,.94)", color: "#e8edf4",
      font: "600 34px/1.35 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif",
      letterSpacing: "-.02em", opacity: "0", transition: "opacity .45s ease",
      whiteSpace: "pre-line",
    });
    document.body.appendChild(d);
    requestAnimationFrame(() => (d.style.opacity = "1"));
  }, text);
  await sleep(ms);
  await page.evaluate(() => {
    const d = document.getElementById("__card");
    if (d) { d.style.opacity = "0"; setTimeout(() => d.remove(), 500); }
  });
  await sleep(600);
}

async function press(selector, expect, { hold = 1600, nth = 0, timeout = 40000 } = {}) {
  const before = await page.$eval("#log", (e) => e.textContent);
  await page.evaluate((s, n) => document.querySelectorAll(s)[n].click(), selector, nth);
  const t0 = Date.now();
  for (;;) {
    const now = await page.$eval("#log", (e) => e.textContent);
    if (now !== before && (!expect || now.includes(expect))) break;
    if (Date.now() - t0 > timeout) {
      throw new Error(`step did not produce ${JSON.stringify(expect)} — log tail: ` + now.slice(-200));
    }
    await sleep(400);
  }
  await sleep(hold);
}

fs.mkdirSync(path.dirname(out), { recursive: true });
await page.goto(BASE + "/index.html", { waitUntil: "networkidle2" });
await rec.start(out);

// 1–2 · the hook: an opinion judge and re-execution disagreeing over money.
await card("An agent paid another agent.\nThey disagree. Who decides?", 3000);
await page.evaluate(() => document.getElementById("btnFalse")?.click());
await sleep(600);
await page.evaluate(() => document.getElementById("btnReplay")?.click());
await sleep(11000);
await card("One reads the claim.\nThe other replays the work.", 2800);
await page.evaluate(() => document.querySelector(".drive")?.scrollIntoView({ behavior: "smooth", block: "center" }));
await sleep(3200);

// 3 · from watching to driving.
await card("Don't take our word for it.", 2400);
await page.goto(BASE + "/arc.html", { waitUntil: "networkidle2" });
await sleep(1800);

// 4 · fund, then TRY TO STEAL IT, then settle honestly. The order matters: a theft
//     attempt against an already-settled deal reverts with BadState() and proves
//     nothing about the binding. The first recording of this cut got that wrong and
//     the guard below refused to ship it.
await press('button[data-act="fund"][data-deal="honest"]', "tx 0x", { hold: 2000 });
await card("A conditional USDC payment.\nThe condition is a proof.", 2600);

// 5 · the beat: a real proof of the wrong execution, against a funded deal.
await press('button[data-act="settle"][data-proof="decrease"]', "BindingMismatch", { hold: 4200 });
await card("A real proof. Of the wrong execution.\nThe money does not move.", 3200);

await press('button[data-act="settle"][data-deal="honest"]:not([data-proof])', "tx 0x", { hold: 2600 });
await card("The deal's own proof releases it.", 2400);

// 6 · the other direction.
await press('button[data-act="fund"][data-deal="decrease"]', "tx 0x", { hold: 1400 });
await press('button[data-act="settle"][data-deal="decrease"]', "tx 0x", { hold: 2400 });
await card("And when the work did not reproduce,\nthe buyer is made whole.", 2600);

// 7 · the sentence this repository exists to make true.
await press('button[data-act="fund"][data-deal="solana"]', "tx 0x", { hold: 1400 });
await press('button[data-act="settle"][data-deal="solana"]', "tx 0x", { hold: 2600 });
await card("USDC on Arc.\nReleased by a proof about work performed on Solana.\nNo bridge. No light client.", 3600);

// 8 · nobody ever proves anything.
await press('button[data-act="fund"][data-deal="abandoned"]', "tx 0x", { hold: 1200 });
await press('button[data-act="refund"][data-deal="abandoned"]', "TooEarly", { hold: 2600, nth: 0 });
await press('button[data-act="warp"]', null, { hold: 1200 });
await press('button[data-act="refund"][data-deal="abandoned"]', "tx 0x", { hold: 2600, nth: 1 });
await card("And if nobody ever proves anything,\nthe money still comes home.", 2800);

// 8b · the same contract, on the PUBLIC chain, checked live in the browser being
// filmed. Everything above is a local anvil at Arc's chain id — honest, reproducible,
// and worth nothing as evidence that anyone deployed anything. This beat is the
// evidence, so the recorder refuses to film it unless the page's own checks go green
// and the hashes it shows are the ones the repository recorded.
{
  const rec_ = JSON.parse(fs.readFileSync(
    path.join(repo, "zk-verdict", "contracts", "arc.json"), "utf8"));
  const txs = Object.values(rec_.deployedByReckn.settlements).map((x) => x.tx);
  if (txs.length < 4) throw new Error(`arc.json records only ${txs.length} settlements`);

  await card("Everything you just saw was a local chain.\nThis one is not.", 2800);
  await page.goto(LIVE + "/", { waitUntil: "networkidle2" });

  // The page talks to Arc from the browser; give the RPC time and require GREEN.
  await page.waitForFunction(
    () => document.querySelector("#s-code")?.textContent === "\u2713" &&
          document.querySelectorAll("#rows .ok").length >= 4 &&
          document.querySelector("#s-frozen")?.textContent === "\u2713",
    { timeout: 60000 },
  ).catch(() => { throw new Error("the live page did not reach a green state — refusing " +
                                  "to film a check that did not pass"); });

  const shown = await page.$eval("main", (e) => e.innerHTML);
  for (const tx of txs) {
    if (!shown.includes(tx)) {
      throw new Error(`the live page does not carry the recorded settlement ${tx}`);
    }
  }
  const code = await page.$eval("#t-code", (e) => e.textContent);
  if (!/byte-identical/.test(code)) throw new Error("bytecode check is not green: " + code);

  await sleep(2600);
  await page.evaluate(() =>
    document.getElementById("rows")?.scrollIntoView({ behavior: "smooth", block: "center" }));
  await sleep(3400);
}
await card("USDC on Arc testnet. Four settlements.\nTwo of them decided by proofs about Solana.", 3400);
await card("Your browser just checked the bytecode\nagainst the source. Not a screenshot.", 3200);

// 9 · the build condition, in this run's own bytes.
await page.setContent(`<!doctype html><meta charset="utf-8"><style>
  body{margin:0;background:#05070a;color:#e8edf4;font:13.5px/1.55 ui-monospace,SFMono-Regular,Menlo,monospace;
       display:flex;align-items:center;justify-content:center;height:100vh}
  pre{margin:0;padding:26px 30px;white-space:pre-wrap}
  .g{color:#3fb950}</style>
  <pre>${noKeys.replace(/[<&]/g, (c) => (c === "<" ? "&lt;" : "&amp;"))
        .replace(/(✓[^\n]*)/g, '<span class="g">$1</span>')}</pre>`);
await sleep(4200);
await card("There is no key that can move a funded escrow.\nIt is a build condition, not a promise.", 3400);

await rec.stop();
await browser.close();
stopDemo();

const secs = execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration",
  "-of", "default=nw=1:nk=1", out], { encoding: "utf8" }).trim();
const mb = (fs.statSync(out).size / 1e6).toFixed(1);
console.error(`\n✓ ${path.relative(repo, out)}  ${Number(secs).toFixed(1)}s  ${mb} MB`);
