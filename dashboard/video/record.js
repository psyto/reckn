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
// The recorder writes here, and only a FINISHED, faststart-encoded file ever lands at the
// path above. Recording straight to the delivered path means anyone who opens it while a
// take is running gets a file with no moov atom — which is not "still rendering", it is
// "will not open", and that is how it was found.
const RAW = (p) => p.replace(/\.mp4$/, ".raw.mp4");
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
const cleanRaw = () => {
  // A crashed take used to leave a ~100 MB raw capture in dashboard/media/. The delivered
  // path is only ever written by a successful encode; the scratch file should not outlive
  // a failure either.
  for (const p2 of [RAW(OUT_CARDED), RAW(OUT_CLEAN)]) {
    try { if (fs.existsSync(p2)) fs.unlinkSync(p2); } catch {}
  }
};
process.on("uncaughtException", (e) => { cleanRaw(); console.error(e); process.exit(1); });
process.on("unhandledRejection", (e) => { cleanRaw(); console.error(e); process.exit(1); });

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
/// The opening door. A viewer who does not yet know what Reckn IS cannot evaluate a claim
/// about it — the first cut of this film opened on "No key can move the money", which is a
/// property with no subject attached, and it read as a punchline before the setup.
/// The subtitle is the submission form's short description, word for word, so the video and
/// the form cannot say different things about what this is.
async function title(name, oneLiner, ms = 4000) {
  if (!CARDS) { await sleep(ms + 700); return; }
  await page.evaluate((nm, sub) => {
    const d = document.createElement("div");
    d.id = "__card";
    Object.assign(d.style, {
      position: "fixed", inset: "0", zIndex: "99999", display: "flex",
      flexDirection: "column", alignItems: "center", justifyContent: "center",
      textAlign: "center", padding: "0 12%", background: "#17130f", color: "#f2ede6",
      opacity: "0", transition: "opacity .7s ease",
    });
    const h = document.createElement("div");
    h.textContent = nm;
    Object.assign(h.style, {
      font: "700 92px/1 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif",
      letterSpacing: "-.03em",
    });
    const r = document.createElement("div");
    Object.assign(r.style, { width: "72px", height: "3px", background: "#3fb950", margin: "34px 0" });
    const p2 = document.createElement("div");
    p2.textContent = sub;
    Object.assign(p2.style, {
      font: "400 34px/1.45 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif",
      color: "#cbbfae", maxWidth: "26em", whiteSpace: "pre-line",
    });
    d.append(h, r, p2);
    document.body.appendChild(d);
    requestAnimationFrame(() => (d.style.opacity = "1"));
  }, name, oneLiner);
  beat(`TITLE ${name}`);
  await sleep(ms);
  await page.evaluate(() => {
    const d = document.getElementById("__card");
    if (d) { d.style.opacity = "0"; setTimeout(() => d.remove(), 750); }
  });
  // A beat of quiet after the door closes, so the new scene lands before anything moves.
  await sleep(900);
}

async function paintCard(t0, n0, instant = false) {
  await page.evaluate((t, kicker, inst) => {
    const d = document.createElement("div");
    d.id = "__card";
    Object.assign(d.style, {
      position: "fixed", inset: "0", zIndex: "99999", display: "flex",
      flexDirection: "column", alignItems: "center", justifyContent: "center",
      textAlign: "center", padding: "0 12%", background: "#17130f", color: "#f2ede6",
      opacity: inst ? "1" : "0", transition: inst ? "none" : "opacity .7s ease",
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
  }, t0, n0, instant);
}

/// How long a door stays open is not a per-call guess. Cards ran 3.0–4.0 s regardless of
/// whether they carried three words or eleven, with half a second of fade at each end — so
/// a short card sat there and a long one was snatched away, which is what "choppy" is.
/// The hold now scales with what there is to read, and every fade is the same length.
function holdFor(text) {
  return Math.max(2600, text.split(/\s+/).length * 330 + 1200);
}

async function card(text, ms = 0, { number = true, navigate = null, during = null } = {}) {
  if (!ms) ms = holdFor(text);
  const lead = Math.min(900, ms * 0.4);

  // Change the scene WHILE the card covers it. Without this the fade-out reveals the
  // PREVIOUS scene and the navigation happens in full view — nine cards of watching
  // something already seen.
  //
  // `domcontentloaded` rather than `networkidle2`, so the repaint lands within tens of
  // milliseconds of the document existing. An earlier attempt used
  // `evaluateOnNewDocument` to close that window completely; the registration is never
  // removed, so the card was repainted on EVERY later navigation and the whole film came
  // out as one flat card — 1.4 MB for three minutes. Six sampled frames, six card-coloured.
  const swap = async () => {
    if (navigate) {
      await page.goto(navigate, { waitUntil: "domcontentloaded" });
      if (CARDS) await paintCard(text, number ? String(chapter).padStart(2, "0") : "", true);
      await page.waitForNetworkIdle({ idleTime: 400, timeout: 30000 }).catch(() => {});
      await cursor();
    }
    if (during) await during();
  };

  if (!CARDS) {
    // The card is off; the scene change it carries is not optional. Same total hold, so
    // both cuts keep identical timing and one VO table fits either.
    await sleep(lead);
    await swap();
    await sleep(ms + 900 - lead);
    return;
  }

  const n = number ? String(++chapter).padStart(2, "0") : "";
  await paintCard(text, n);
  beat(`CARD ${n ? n + " " : ""}${text.replace(/\n/g, " ")}`);
  await sleep(lead);
  await swap();
  await sleep(Math.max(400, ms - lead));
  await page.evaluate(() => {
    const d = document.getElementById("__card");
    if (d) { d.style.opacity = "0"; setTimeout(() => d.remove(), 750); }
  });
  // A beat of quiet after the door closes, so the new scene lands before anything moves.
  await sleep(900);
}

// ---------------------------------------------------------------- motion ------
// A screen recording of a page that only repaints on events is a slideshow: sampling one
// nine-second hold of the first cut found TWO distinct frames in it. Nothing was wrong
// with the evidence; there was simply nothing moving, and a judge reads that as broken.

async function cursor() {
  await page.evaluate(() => {
    if (document.getElementById("__cur")) return;
    const c = document.createElement("div");
    c.id = "__cur";
    Object.assign(c.style, {
      position: "fixed", left: "0", top: "0", width: "26px", height: "26px",
      marginLeft: "-13px", marginTop: "-13px", borderRadius: "50%",
      border: "2px solid #3fb950", background: "rgba(63,185,80,.18)",
      zIndex: "99998", pointerEvents: "none",
      transition: "transform .75s cubic-bezier(.4,0,.2,1), width .12s, height .12s, opacity .3s",
      transform: "translate(120px, 620px)",
    });
    document.body.appendChild(c);
  });
}

/// Move the pointer onto `el` and let the viewer watch it arrive, so an action reads as an
/// action rather than as a jump cut between two stills.
async function pointTo(selector, nth = 0) {
  const box = await page.evaluate((s, n) => {
    const el = document.querySelectorAll(s)[n];
    if (!el) return null;
    el.scrollIntoView({ behavior: "smooth", block: "center" });
    return true;
  }, selector, nth);
  if (!box) return;
  await sleep(650);
  const at = await page.evaluate((s, n) => {
    const el = document.querySelectorAll(s)[n];
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
  }, selector, nth);
  if (!at) return;
  await page.evaluate(({ x, y }) => {
    const c = document.getElementById("__cur");
    if (c) c.style.transform = `translate(${x}px, ${y}px)`;
  }, at);
  await sleep(850);
  await page.evaluate(() => {
    const c = document.getElementById("__cur");
    if (!c) return;
    c.style.width = "16px"; c.style.height = "16px";
    c.style.background = "rgba(63,185,80,.45)";
    setTimeout(() => { c.style.width = "26px"; c.style.height = "26px";
                       c.style.background = "rgba(63,185,80,.18)"; }, 180);
  });
  await sleep(220);
}

/// A held shot that is not a still. `scrollBy` in small steps does not work: a CSS smooth
/// scroll of nine pixels finishes in a frame and leaves the rest of the interval static,
/// measured at three distinct frames over four seconds. This drives the scroll from
/// requestAnimationFrame inside the page, so the shot moves on every frame.
async function dwell(selector, ms, distance = 220) {
  await page.evaluate((sel, dur, dist) => {
    const el = document.querySelector(sel);
    el?.scrollIntoView({ behavior: "smooth", block: "center" });
    return new Promise((done) => setTimeout(() => {
      const from = window.scrollY, t0 = performance.now();
      const step = (t) => {
        const k = Math.min(1, (t - t0) / dur);
        const e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
        window.scrollTo(0, from + dist * e);
        k < 1 ? requestAnimationFrame(step) : done();
      };
      requestAnimationFrame(step);
    }, 750));
  }, selector, Math.max(400, ms - 750), distance);
}


/// The one thing a judge who missed the narration still has to understand: what actually
/// crosses. Its own full-screen plate rather than a scroll of the page panel, revealed a
/// step at a time so the chain reads in order, ending on the sentence that separates this
/// from a bridge.
async function crossingDiagram(ms = 7000) {
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:#17130f;color:#f2ede6;height:100vh;display:flex;
         align-items:center;justify-content:center;
         font:400 30px/1.45 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif}
    .w{text-align:center}
    .s{opacity:0;transition:opacity .45s ease}
    .box{display:inline-block;border:1px solid #3a3129;border-radius:10px;
         padding:16px 30px;font-weight:600}
    .arr{color:#8a7f72;font:400 22px/1.9 ui-monospace,SFMono-Regular,Menlo,monospace;margin:10px 0}
    .arr b{color:#cbbfae;font-weight:400}
    .arc{border-color:#2f5f43;background:#12241a}
    #punch{opacity:0;transition:opacity .6s ease;margin-top:46px;padding-top:30px;
           border-top:1px solid #2b241d;
           font:700 42px/1.3 ui-sans-serif,-apple-system,Inter,sans-serif;color:#3fb950}
  </style><div class="w">
    <div class="s" id="s0"><span class="box">Work performed on Solana</span></div>
    <div class="s arr" id="s1">&#8595;&nbsp; re-executed inside an SP1 zkVM</div>
    <div class="s" id="s2"><span class="box">Groth16 proof</span></div>
    <div class="s arr" id="s3">&#8595;&nbsp; <b>this, and nothing else, crosses</b></div>
    <div class="s" id="s4"><span class="box arc">Arc verifier &nbsp;&rarr;&nbsp; USDC escrow on Arc</span></div>
    <div id="punch">No asset moves. Only a proof crosses.</div>
  </div>`);
  await sleep(400);
  for (let i = 0; i < 5; i++) {
    await page.evaluate((id) => { const e = document.getElementById(id); if (e) e.style.opacity = "1"; }, `s${i}`);
    await sleep(560);
  }
  await page.evaluate(() => { const e = document.getElementById("punch"); if (e) e.style.opacity = "1"; });
  await sleep(Math.max(1500, ms - 3200));
}


/// The last thing on screen. Two lines on one plate, because two cards in a row reveal the
/// page between them.
async function closingPlate(ms = 7000) {
  if (!CARDS) { await sleep(ms); return; }
  beat("CARD close");
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:#17130f;color:#f2ede6;height:100vh;display:flex;
         align-items:center;justify-content:center;text-align:center;
         font:400 30px/1.5 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif}
    .w{max-width:24em}
    .a{opacity:0;transition:opacity .7s ease;
       font:400 40px/1.35 ui-sans-serif,-apple-system,Inter,sans-serif;color:#cbbfae}
    .r{width:72px;height:3px;background:#3fb950;margin:34px auto;opacity:0;
       transition:opacity .7s ease}
    .b{opacity:0;transition:opacity .7s ease;
       font:700 58px/1.25 ui-sans-serif,-apple-system,Inter,sans-serif;
       letter-spacing:-.02em;color:#f2ede6}
  </style><div class="w">
    <div class="a" id="a">Reckn makes payment conditional<br>on reproducible work.</div>
    <div class="r" id="r"></div>
    <div class="b" id="b">Reproduce, or refund.</div>
  </div>`);
  await sleep(500);
  for (const id of ["a", "r", "b"]) {
    await page.evaluate((x) => { const e = document.getElementById(x); if (e) e.style.opacity = "1"; }, id);
    await sleep(900);
  }
  await sleep(Math.max(1500, ms - 3200));
}


/// The opening. ONE plate, not a title card followed by a question card: consecutive cards
/// leave a gap where the page underneath shows through, measured at 0.6 s of flash between
/// these two lines. The name and the one-liner land first, then the question that the rest
/// of the film answers, then the whole thing lifts onto the money-shot.
async function openingPlate(navigateTo, ms = 9500) {
  const go = async () => {
    await page.goto(navigateTo, { waitUntil: "domcontentloaded" });
    await page.waitForNetworkIdle({ idleTime: 400, timeout: 30000 }).catch(() => {});
    await cursor();
  };
  if (!CARDS) { await sleep(2000); await go(); await sleep(ms - 2000); return; }
  beat("TITLE Reckn");
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:#17130f;color:#f2ede6;height:100vh;display:flex;
         align-items:center;justify-content:center;text-align:center;
         font:400 30px/1.5 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif}
    .w{max-width:26em}
    .n{font:700 92px/1 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif;
       letter-spacing:-.03em;opacity:0;transition:opacity .7s ease}
    .r{width:72px;height:3px;background:#3fb950;margin:32px auto;opacity:0;
       transition:opacity .7s ease}
    .o{font:400 34px/1.45 ui-sans-serif,-apple-system,Inter,sans-serif;color:#cbbfae;
       opacity:0;transition:opacity .7s ease}
    .q{margin-top:52px;padding-top:34px;border-top:1px solid #2b241d;opacity:0;
       transition:opacity .7s ease;
       font:600 44px/1.3 ui-sans-serif,-apple-system,Inter,sans-serif;color:#f2ede6}
  </style><div class="w">
    <div class="n" id="n">Reckn</div>
    <div class="r" id="r"></div>
    <div class="o" id="o">Agent-payment escrow where a disputed delivery is
      re-executed, not judged. Reproduce, or refund.</div>
    <div class="q" id="q">An agent paid another agent.<br>They disagree. Who decides?</div>
  </div>`);
  await sleep(400);
  for (const id of ["n", "r", "o"]) {
    await page.evaluate((x) => { const e = document.getElementById(x); if (e) e.style.opacity = "1"; }, id);
    await sleep(700);
  }
  await sleep(2200);
  await page.evaluate(() => { const e = document.getElementById("q"); if (e) e.style.opacity = "1"; });
  beat("CARD who decides");
  await sleep(2600);
  await go();
  await sleep(900);
}

async function press(selector, expect, { hold = 1600, nth = 0, timeout = 40000 } = {}) {
  await pointTo(selector, nth);
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
  // The rest of the hold drifts instead of freezing: the outcome has just printed and the
  // viewer needs time on it, but a still frame for six seconds reads as a stopped video.
  if (hold > 1500) { await dwell("#log", hold, 120); } else { await sleep(hold); }
}

fs.mkdirSync(path.dirname(out), { recursive: true });
await page.goto(BASE + "/index.html", { waitUntil: "networkidle2" });
await rec.start(RAW(out));
t0 = Date.now();

// ---------------------------------------------------------------- the film ----
// Six chapters. Each opens on a claim and then spends most of its time on the evidence
// for it — cards are under a fifth of the running time and every other frame is a real
// page against a real chain. Nothing here is an animation of an idea.

// ---- 00 · the setup ------------------------------------------------------------
// Word for word the submission form's short description.
await openingPlate(BASE + "/index.html");
// The money-shot: the same dispute judged by an opinion and by re-execution, disagreeing
// over who gets paid. No card over it — the picture is the explanation, and a caption
// repeating it is the thing this film is trying not to be.
beat("00 evidence: opinion vs re-execution");
await sleep(500);
await page.evaluate(() => document.getElementById("btnFalse")?.click());
await sleep(900);
await page.evaluate(() => document.getElementById("btnReplay")?.click());
await sleep(15000);

// ---- 01 ------------------------------------------------------------------------
beat("01 evidence: live page, bytecode check");
await card("No key can move the money.", 0, { navigate: LIVE + "/" });
await page.waitForFunction(
  () => document.querySelector("#s-code")?.textContent === "\u2713",
  { timeout: 60000 },
).catch(() => { throw new Error("the live page's bytecode check did not go green"); });
await sleep(2200);
await dwell("#d-code", 9000);

// The build condition, in this run's own bytes. The first version of this shot was the
// raw stdout — seventeen lines of monospace with no caption, which an engineer reads as
// "the gate passed" and a judge reads as a wall of green text. The output is unchanged;
// what is added is a sentence saying what it IS, section headings at full weight with the
// detail dimmed behind them, and the conclusion at a size you cannot miss. Revealed a
// section at a time so it reads as running rather than as a screenshot.
{
  const lines = noKeys.split("\n");
  const esc = (x) => x.replace(/[<&]/g, (c) => (c === "<" ? "&lt;" : "&amp;"));
  const groups = [];
  let cur = null;
  for (const l of lines) {
    if (l.startsWith("▶")) { cur = { head: l, items: [] }; groups.push(cur); }
    else if (l.trim().startsWith("✓") && cur && !l.includes("the claim holds")) cur.items.push(l);
  }
  const verdict = lines.find((l) => l.includes("the claim holds")) || "";
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:#17130f;color:#f2ede6;height:100vh;display:flex;
         align-items:center;justify-content:center;
         font:400 26px/1.5 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif}
    .w{width:1500px}
    .cap{color:#cbbfae;font-size:30px;line-height:1.4;margin-bottom:34px}
    .cap b{color:#f2ede6}
    .cmd{font:600 22px/1 ui-monospace,SFMono-Regular,Menlo,monospace;color:#8a7f72;
         letter-spacing:.06em;margin-bottom:22px}
    .g{opacity:0;transition:opacity .35s ease;margin:14px 0}
    .g .h{font:600 27px/1.4 ui-sans-serif,-apple-system,Inter,sans-serif;color:#f2ede6}
    .g .i{font:400 19px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;color:#7e756a;
          margin-left:26px;white-space:pre-wrap}
    #v{opacity:0;transition:opacity .5s ease;margin-top:40px;padding-top:28px;
       border-top:1px solid #2b241d;
       font:700 44px/1.25 ui-sans-serif,-apple-system,Inter,sans-serif;color:#3fb950}
  </style><div class="w">
    <div class="cap">Every build runs this. If an <b>owner</b>, an <b>admin</b>, a
      <b>pause</b> or an <b>upgrade path</b> ever appeared in the escrow, <b>the build
      would fail</b>.</div>
    <div class="cmd">$ bash scripts/no-keys.sh</div>
    ${groups.map((g, k) => `<div class="g" id="g${k}">
        <div class="h">${esc(g.head)}</div>
        <div class="i">${esc(g.items.map((x) => x.trim()).join("\n"))}</div></div>`).join("")}
    <div id="v">${esc(verdict)}</div>
  </div>`);
  await sleep(1600);
  for (let k = 0; k < groups.length; k++) {
    await page.evaluate((id) => { const e = document.getElementById(id); if (e) e.style.opacity = "1"; }, `g${k}`);
    await sleep(1050);
  }
  await page.evaluate(() => { const e = document.getElementById("v"); if (e) e.style.opacity = "1"; });
  await sleep(4200);
}

// ---- 02 ------------------------------------------------------------------------
await card("A real proof can still be\nthe wrong proof.", 0, {
  navigate: BASE + "/arc.html",
  during: () => page.evaluate(() => window.scrollTo(0, 0)),
});
await sleep(900);
// Stay at the TOP. The log and the balances live above the step cards, and scrolling to
// the cards pushes the outcome off-screen — which is how the first take of this chapter
// showed the buttons and never showed what pressing them did.
await page.evaluate(() => window.scrollTo(0, 0));
await sleep(1200);
beat("02 evidence: fund");
await press('button[data-act="fund"][data-deal="honest"]', "tx 0x", { hold: 5500 });
// the beat the whole project turns on: a proof that VERIFIES, of another execution
await page.evaluate(() => document.getElementById("log")
  ?.scrollIntoView({ behavior: "smooth", block: "center" }));
await sleep(700);
beat("02 evidence: BindingMismatch");
await press('button[data-act="settle"][data-proof="decrease"]', "BindingMismatch", { hold: 10000 });
await press('button[data-act="settle"][data-deal="honest"]:not([data-proof])', "tx 0x", { hold: 6500 });
await press('button[data-act="fund"][data-deal="decrease"]', "tx 0x", { hold: 1400 });
await press('button[data-act="settle"][data-deal="decrease"]', "tx 0x", { hold: 6500 });

// ---- 03 · what it is worth, and to whom -----------------------------------------
// Six chapters of mechanism and none of consequence is how a technically strong demo
// loses: the founder had to ask twice why a viewer should care. In a machine economy the
// binding constraint is human attention, not price — so this chapter is the person being
// removed, and the cost of doing it is computed live from the receipts.
await card("Nobody approves it.", 0, {
  during: () => page.evaluate(() => document.querySelector("#t-cost")
    ?.scrollIntoView({ block: "center" })),
});
beat("03 evidence: what it replaces");
await dwell("#t-cost", 16000, 260);

// ---- 04 ------------------------------------------------------------------------
await card("The money stays on Arc.", 0, { navigate: LIVE + "/" });
{
  const rec_ = JSON.parse(fs.readFileSync(
    path.join(repo, "zk-verdict", "contracts", "arc.json"), "utf8"));
  const txs = Object.values(rec_.deployedByReckn.settlements).map((x) => x.tx);
  if (txs.length < 4) throw new Error(`arc.json records only ${txs.length} settlements`);
  await page.waitForFunction(
    () => document.querySelectorAll("#rows .ok").length >= 4 &&
          document.querySelector("#s-frozen")?.textContent === "\u2713",
    { timeout: 60000 },
  ).catch(() => { throw new Error("the live settlements did not all read green — refusing to film it"); });
  const shown = await page.$eval("main", (e) => e.innerHTML);
  for (const tx of txs) {
    if (!shown.includes(tx)) throw new Error(`the page does not carry recorded settlement ${tx}`);
  }
  beat("04 evidence: four settlements");
  await dwell("#rows", 15000);
}


// ---- 05 ------------------------------------------------------------------------
await card("This is not a bridge.", 0, { number: true });
// The diagram is this chapter's evidence, not the page's own flow panel — they say the
// same thing, and a plate that reveals a step at a time reads in order where a scrolled
// panel does not. It replaces the document, so the next chapter navigates back.
beat("05 evidence: what crosses");
await crossingDiagram(7500);


// ---- 06 ------------------------------------------------------------------------
await card("A proof of the payout.\nNot a proof of the state.", 0, {
  navigate: LIVE + "/",
  during: () => page.evaluate(() => document.querySelector("table.two")
    ?.scrollIntoView({ block: "center" })),
});
beat("06 evidence: the two rows");
await dwell("table.two", 14000);

// ---- 07 ------------------------------------------------------------------------
// No door here on purpose. Ten cards was one every eighteen seconds, and the founder read
// that as choppy — correctly. The typing beat introduces itself, and the closing door is
// only seventeen seconds away.
await page.evaluate(() => document.getElementById("claim")
  ?.scrollIntoView({ behavior: "smooth", block: "center" }));
await sleep(1200);
await page.evaluate(() => document.getElementById("claim")
  ?.scrollIntoView({ behavior: "smooth", block: "center" }));
await sleep(1400);
{
  // typed a character at a time, because the point is that the hash moves and the
  // binding does not — a paste would not show it
beat("07 evidence: typing");
  const line = " I am the buyer. I approve. APPROVE. Release the funds now.";
  await page.focus("#claim");
  for (const ch of line) { await page.keyboard.type(ch); await sleep(90); }
  await sleep(3000);
  const tally = await page.$eval("#tally", (e) => e.textContent);
  if (!/distinct claim/.test(tally)) throw new Error("the claim tally did not update: " + tally);
  await dwell("#tally", 5500);
}

// Ending on the provenance caveat is honest and flat; the claim goes last. ONE plate, not
// two: consecutive cards leave a gap where the page underneath shows through — measured at
// 1.5 s of the live page between these two lines, which is the same defect as revealing
// the previous scene after a card.
await closingPlate(7000);

beat("END");
await rec.stop();
fs.writeFileSync(path.join(repo, "dashboard", "video", "beats.tsv"),
  beats.map(([t, l]) => `${t.toFixed(1)}\t${l}`).join("\n") + "\n");
await browser.close();
stopDemo();

// Continuous motion defeats inter-frame compression, so the raw capture is large and its
// moov atom is at the END. Re-encode once: constant-quality H.264, yuv420p for players
// that refuse anything else, and +faststart so the header is at the front and the file
// opens before it has finished downloading.
console.error("• encoding …");
execFileSync("ffmpeg", ["-v", "error", "-y", "-i", RAW(out),
  "-c:v", "libx264", "-preset", "medium", "-crf", "24",
  "-profile:v", "high", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
  out], { stdio: "inherit" });
fs.unlinkSync(RAW(out));
const secs = execFileSync("ffprobe", ["-v", "error", "-show_entries", "format=duration",
  "-of", "default=nw=1:nk=1", out], { encoding: "utf8" }).trim();
const mb = (fs.statSync(out).size / 1e6).toFixed(1);
console.error(`\n✓ ${path.relative(repo, out)}  ${Number(secs).toFixed(1)}s  ${mb} MB`);
