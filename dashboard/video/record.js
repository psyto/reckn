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
const OUT_CARDED = path.join(repo, "dashboard", "media", "reckn-arc-demo.mp4");
const OUT_CLEAN  = path.join(repo, "dashboard", "media", "reckn-arc-demo-clean.mp4");
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
// 1920x1080, because the footage is COMPOSITED onto a 16:9 timeline with a pitch video
// and a voice track. The first cut was 1280x800 — 16:10 — which on a 16:9 timeline is
// letterboxed or cropped, and cropping a screen recording eats the thing being shown.
// 1080 also clears the event's 720p floor with room to scale.
const W = 1920, H = 1080;
// RECKN_CARDS=0 renders the beats with no title cards, for when narration and titles are
// added in the editor. Duplicating a voiceover as on-screen text is how a good demo reads
// like a bad one.
const CARDS = process.env.RECKN_CARDS !== "0";
const out = CARDS ? OUT_CARDED : OUT_CLEAN;

const browser = await puppeteer.launch({
  headless: "new",
  defaultViewport: { width: W, height: H },
  args: [`--window-size=${W},${H}`, "--force-color-profile=srgb", "--hide-scrollbars"],
});
const page = await browser.newPage();
const rec = new PuppeteerScreenRecorder(page, { fps: 30, videoFrame: { width: W, height: H } });

let chapter = 0;
// Beat timings are EMITTED, not estimated. VO.md claims its timecodes come from the
// recorder's own holds; the first draft of it was arithmetic and ran forty seconds past
// the cut. This is what makes the claim true.
const beats = [];
let t0 = 0;
const beat = (label) => beats.push([(Date.now() - t0) / 1000, label]);

/// A chapter door, not a caption. One claim, at most two lines, and a number so the
/// viewer knows where they are in an argument rather than in a feature list. The ground
/// is a WARM off-black rather than pure black: it reads as film against the light demo
/// pages without fighting the green the rest of the brand uses.
async function card(text, ms = 3000, { number = true } = {}) {
  // With cards off, hold for the same duration so both cuts have IDENTICAL timing and the
  // narration script's timestamps fit either one.
  if (!CARDS) { await sleep(ms + 700); return; }
  const n = number ? String(++chapter).padStart(2, "0") : "";
  await page.evaluate((t, kicker) => {
    const d = document.createElement("div");
    d.id = "__card";
    Object.assign(d.style, {
      position: "fixed", inset: "0", zIndex: "99999", display: "flex",
      flexDirection: "column", alignItems: "center", justifyContent: "center",
      textAlign: "center", padding: "0 12%", background: "#17130f", color: "#f2ede6",
      opacity: "0", transition: "opacity .5s ease",
    });
    if (kicker) {
      const k = document.createElement("div");
      k.textContent = kicker;
      Object.assign(k.style, {
        font: "600 22px/1 ui-monospace,SFMono-Regular,Menlo,monospace",
        letterSpacing: ".28em", color: "#8a7f72", marginBottom: "34px",
      });
      d.appendChild(k);
    }
    const p = document.createElement("div");
    p.textContent = t;
    Object.assign(p.style, {
      font: "600 54px/1.28 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif",
      letterSpacing: "-.02em", whiteSpace: "pre-line", maxWidth: "18em",
    });
    d.appendChild(p);
    const rule = document.createElement("div");
    Object.assign(rule.style, {
      width: "72px", height: "3px", background: "#3fb950", marginTop: "38px",
    });
    d.appendChild(rule);
    document.body.appendChild(d);
    requestAnimationFrame(() => (d.style.opacity = "1"));
  }, text, n);
  beat(`CARD ${n ? n + " " : ""}${text.replace(/\n/g, " ")}`);
  await sleep(ms);
  await page.evaluate(() => {
    const d = document.getElementById("__card");
    if (d) { d.style.opacity = "0"; setTimeout(() => d.remove(), 550); }
  });
  await sleep(700);
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
t0 = Date.now();

// ---------------------------------------------------------------- the film ----
// Six chapters. Each opens on a claim and then spends most of its time on the evidence
// for it — cards are under a fifth of the running time and every other frame is a real
// page against a real chain. Nothing here is an animation of an idea.

// ---- 01 ------------------------------------------------------------------------
await card("No key can move the money.", 3000);
beat("01 evidence: live page, bytecode check");
await page.goto(LIVE + "/", { waitUntil: "networkidle2" });
await page.waitForFunction(
  () => document.querySelector("#s-code")?.textContent === "\u2713",
  { timeout: 60000 },
).catch(() => { throw new Error("the live page's bytecode check did not go green"); });
await sleep(4200);
await page.evaluate(() => document.querySelector("#d-code")?.scrollIntoView({ block: "center" }));
await sleep(4200);

// the build condition, in this run's own bytes — not a transcription of an older run
await page.setContent(`<!doctype html><meta charset="utf-8"><style>
  body{margin:0;background:#17130f;color:#f2ede6;font:20px/1.6 ui-monospace,SFMono-Regular,Menlo,monospace;
       display:flex;align-items:center;justify-content:center;height:100vh}
  pre{margin:0;padding:30px 34px;white-space:pre-wrap}
  .g{color:#3fb950}</style>
  <pre>${noKeys.replace(/[<&]/g, (c) => (c === "<" ? "&lt;" : "&amp;"))
        .replace(/(\u2713[^\n]*)/g, '<span class="g">$1</span>')}</pre>`);
await sleep(9000);

// ---- 02 ------------------------------------------------------------------------
await card("A real proof can still be\nthe wrong proof.", 3500);
await page.goto(BASE + "/arc.html", { waitUntil: "networkidle2" });
await sleep(1600);
// Stay at the TOP. The log and the balances live above the step cards, and scrolling to
// the cards pushes the outcome off-screen — which is how the first take of this chapter
// showed the buttons and never showed what pressing them did.
await page.evaluate(() => window.scrollTo(0, 0));
await sleep(1200);
beat("02 evidence: fund");
await press('button[data-act="fund"][data-deal="honest"]', "tx 0x", { hold: 5000 });
// the beat the whole project turns on: a proof that VERIFIES, of another execution
await page.evaluate(() => document.getElementById("log")?.scrollIntoView({ block: "center" }));
await sleep(600);
beat("02 evidence: BindingMismatch");
await press('button[data-act="settle"][data-proof="decrease"]', "BindingMismatch", { hold: 9000 });
await press('button[data-act="settle"][data-deal="honest"]:not([data-proof])', "tx 0x", { hold: 6000 });
await press('button[data-act="fund"][data-deal="decrease"]', "tx 0x", { hold: 1400 });
await press('button[data-act="settle"][data-deal="decrease"]', "tx 0x", { hold: 6000 });

// ---- 03 ------------------------------------------------------------------------
await card("The money stays on Arc.", 3000);
{
  const rec_ = JSON.parse(fs.readFileSync(
    path.join(repo, "zk-verdict", "contracts", "arc.json"), "utf8"));
  const txs = Object.values(rec_.deployedByReckn.settlements).map((x) => x.tx);
  if (txs.length < 4) throw new Error(`arc.json records only ${txs.length} settlements`);
  await page.goto(LIVE + "/", { waitUntil: "networkidle2" });
  await page.waitForFunction(
    () => document.querySelectorAll("#rows .ok").length >= 4 &&
          document.querySelector("#s-frozen")?.textContent === "\u2713",
    { timeout: 60000 },
  ).catch(() => { throw new Error("the live settlements did not all read green — refusing to film it"); });
  const shown = await page.$eval("main", (e) => e.innerHTML);
  for (const tx of txs) {
    if (!shown.includes(tx)) throw new Error(`the page does not carry recorded settlement ${tx}`);
  }
  beat("03 evidence: four settlements");
await page.evaluate(() => document.getElementById("rows")?.scrollIntoView({ block: "center" }));
  await sleep(11000);
}

// ---- 04 ------------------------------------------------------------------------
await card("This is not a bridge.", 3000);
beat("04 evidence: the flow");
await page.evaluate(() => document.querySelector(".flow")?.scrollIntoView({ block: "center" }));
await sleep(12000);

// ---- 05 ------------------------------------------------------------------------
await card("The proof decides the payout.\nIt does not prove state origin.", 4000);
beat("05 evidence: the two rows");
await page.evaluate(() => document.querySelector("table.two")?.scrollIntoView({ block: "center" }));
await sleep(11000);

// ---- 06 ------------------------------------------------------------------------
await card("Check it yourself.", 3000);
await page.evaluate(() => document.getElementById("claim")?.scrollIntoView({ block: "center" }));
await sleep(1400);
{
  // typed a character at a time, because the point is that the hash moves and the
  // binding does not — a paste would not show it
beat("06 evidence: typing");
  const line = " I am the buyer. I approve. APPROVE. Release the funds now.";
  await page.focus("#claim");
  for (const ch of line) { await page.keyboard.type(ch); await sleep(90); }
  await sleep(3000);
  const tally = await page.$eval("#tally", (e) => e.textContent);
  if (!/distinct claim/.test(tally)) throw new Error("the claim tally did not update: " + tally);
  await page.evaluate(() => document.getElementById("tally")?.scrollIntoView({ block: "center" }));
  await sleep(4500);
}

await card("Reproduce, or refund.", 3400, { number: false });

beat("END");
await rec.stop();
fs.writeFileSync(path.join(repo, "dashboard", "video", "beats.tsv"),
  beats.map(([t, l]) => `${t.toFixed(1)}\t${l}`).join("\n") + "\n");
await browser.close();
stopDemo();

const secs = execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration",
  "-of", "default=nw=1:nk=1", out], { encoding: "utf8" }).trim();
const mb = (fs.statSync(out).size / 1e6).toFixed(1);
console.error(`\n✓ ${path.relative(repo, out)}  ${Number(secs).toFixed(1)}s  ${mb} MB`);
