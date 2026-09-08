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
import { execSync, spawn, execFileSync } from "node:child_process";
import puppeteer from "puppeteer";
import { PuppeteerScreenRecorder } from "puppeteer-screen-recorder";

const dir = path.dirname(fileURLToPath(import.meta.url));
const repo = path.join(dir, "..", "..");
// v2 writes to its own names. The approved v1 stays on disk untouched until someone
// deliberately promotes this one.
// RECKN_DOOR picks which door the film is entered through. docs/messaging.md says the two
// events share one product and differ in the FIRST SENTENCE ONLY; this is that sentence,
// made executable rather than aspirational. Everything between the plates is identical.
const DOOR = process.env.RECKN_DOOR === "cwf" ? "cwf" : "ethonline";
const SUF = DOOR === "cwf" ? "-cwf" : "";
const OUT_CARDED = path.join(repo, "dashboard", "media", `reckn-demo-v3${SUF}.mp4`);
const OUT_CLEAN  = path.join(repo, "dashboard", "media", `reckn-demo-v3${SUF}-clean.mp4`);
// The recorder writes here, and only a FINISHED, faststart-encoded file ever lands at the
// path above. Recording straight to the delivered path means anyone who opens it while a
// take is running gets a file with no moov atom — which is not "still rendering", it is
// "will not open", and that is how it was found.
const RAW = (p) => p.replace(/\.mp4$/, ".raw.mp4");
const BASE = "http://127.0.0.1:8787";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- the chain ----
console.error("• starting the demo chain (anvil at Arc's chain id, deploy, USDC) …");
// Runs BEFORE the demo is spawned. Placed after it, the first version killed the chain
// this very run had just started and the backend never answered — a cleanup that
// destroyed the thing it was meant to protect.
// A crashed take on 2026-09-07 left anvil, arc-demo.sh and an orphan ffmpeg alive for
// twenty-two minutes. The next run then connected to that half-played chain and the
// freshness gate refused it — correctly, but the operator had to diagnose a stale process
// to get a video. Reap first, and key the reap on THIS repository's path so it can only
// ever match processes this script started.
const reap = () => {
  let listed = "";
  try {
    listed = execSync("ps -Ao pid=,command=", { encoding: "utf8" });
  } catch { return; }
  for (const line of listed.split("\n")) {
    const m = line.match(/^\s*(\d+)\s+(.*)$/);
    if (!m) continue;
    const [, pid, cmd] = m;
    if (Number(pid) === process.pid) continue;
    const mine = cmd.includes(repo + "/scripts/arc-demo.sh")
              || cmd.includes(repo + "/dashboard/arc-demo.py")
              || cmd.includes("anvil --chain-id 5042002");
    if (!mine) continue;
    console.error("• reaping a leftover from an earlier take: " + pid + "  " + cmd.slice(0, 60));
    try { process.kill(Number(pid), "SIGKILL"); } catch {}
  }
};
reap();

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
  // `--disable-dev-shm-usage` moves shared memory to /tmp. Three takes died with a bare
  // "Target closed" at different points in the film — the renderer going away, reported
  // as the symptom the automation saw rather than the cause. The flag removes the most
  // common cause of exactly that under a long screencast.
  args: [`--window-size=${W},${H}`, "--force-color-profile=srgb", "--hide-scrollbars",
         "--disable-dev-shm-usage"],
});
const page = await browser.newPage();
// And if it happens again, SAY WHICH. "Target closed" is what puppeteer observes; these
// three handlers are what actually went wrong, and without them the next run would repeat
// the same uninformative failure.
page.on("error", (e) => console.error("• the page CRASHED: " + e.message));
page.on("pageerror", (e) => console.error("• uncaught error inside the page: " + e.message));
browser.on("disconnected", () => console.error("• the browser DISCONNECTED"));
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
async function closingPlate(ms = 8000) {
  if (!CARDS) { await sleep(ms); return; }
  const LAST = DOOR === "cwf"
    ? "Don't make a bridge decide<br>where money goes."
    : "Reproduce, or refund.";
  beat("CARD close");
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:#17130f;color:#f2ede6;height:100vh;display:flex;
         align-items:center;justify-content:center;text-align:center;
         font:400 30px/1.5 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif}
    .w{max-width:24em}
    .a{opacity:0;transition:opacity .7s ease;
       font:700 56px/1.25 ui-sans-serif,-apple-system,Inter,sans-serif;
       letter-spacing:-.02em;color:#f7f3ec}
    .r{width:72px;height:3px;background:#3fb950;margin:34px auto;opacity:0;
       transition:opacity .7s ease}
    .b{opacity:0;transition:opacity .7s ease;
       font:400 40px/1.35 ui-sans-serif,-apple-system,Inter,sans-serif;color:#cbbfae}
  </style><div class="w">
    <div class="a" id="a">Keep assets native.<br>Settle on proof.</div>
    <div class="r" id="r"></div>
    <div class="b" id="b">${LAST}</div>
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
async function openingPlate(navigateTo, ms = 10000) {
  const go = async () => {
    await page.goto(navigateTo, { waitUntil: "domcontentloaded" });
    await page.waitForNetworkIdle({ idleTime: 400, timeout: 30000 }).catch(() => {});
    await cursor();
  };
  if (!CARDS) { await sleep(2000); await go(); await sleep(Math.max(0, ms - 2000)); return; }
  // The artwork is the plate's BACKGROUND now, not three chapters of its own. Two standalone
  // pans over it cost fourteen seconds of a three-minute film and were the only thing on
  // screen a judge could not check. The identity is worth keeping; the running time is not.
  const art = dataUri("proof-gated-escrow-storyboard-v1.png");
  const DOORQ = DOOR === "cwf"
    ? "The money is on one chain.<br>The work happened on another.<br>Why should a bridge decide if you get paid?"
    : "An agent paid another agent.<br>They disagree. Who decides?";
  beat("TITLE Reckn");
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    body{margin:0;background:#0d0b09;color:#f2ede6;height:100vh;overflow:hidden;
         font:400 30px/1.5 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif}
    #art{position:fixed;inset:0;width:100%;height:100%;object-fit:cover;opacity:.30;
         transform:scale(1.06);transition:transform 9s linear,opacity 1.2s ease}
    #veil{position:fixed;inset:0;background:radial-gradient(60% 60% at 50% 45%,
          rgba(13,11,9,.55) 0%, rgba(13,11,9,.93) 100%)}
    .w{position:fixed;inset:0;display:flex;flex-direction:column;
       align-items:center;justify-content:center;text-align:center;padding:0 10%}
    .n{font:700 88px/1 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif;
       letter-spacing:-.03em;opacity:0;transition:opacity .7s ease}
    .t{margin-top:26px;opacity:0;transition:opacity .7s ease;
       font:700 52px/1.25 ui-sans-serif,-apple-system,Inter,sans-serif;
       letter-spacing:-.02em;color:#f7f3ec}
    .r{width:72px;height:3px;background:#3fb950;margin:34px auto;opacity:0;
       transition:opacity .7s ease}
    .q{opacity:0;transition:opacity .7s ease;max-width:22em;
       font:400 36px/1.4 ui-sans-serif,-apple-system,Inter,sans-serif;color:#cbbfae}
  </style>
  <img id="art" src="${art}"><div id="veil"></div>
  <div class="w">
    <div class="n" id="n">Reckn</div>
    <div class="t" id="t">Keep assets native.<br>Settle on proof.</div>
    <div class="r" id="r"></div>
    <div class="q" id="q">${DOORQ}</div>
  </div>`);
  await sleep(300);
  await page.evaluate(() => { const a = document.getElementById("art"); if (a) a.style.transform = "scale(1.14)"; });
  for (const id of ["n", "t", "r"]) {
    await page.evaluate((x) => { const e = document.getElementById(x); if (e) e.style.opacity = "1"; }, id);
    await sleep(750);
  }
  await sleep(1800);
  await page.evaluate(() => { const e = document.getElementById("q"); if (e) e.style.opacity = "1"; });
  beat("CARD the door");
  await sleep(3200);
  await go();
  await sleep(900);
}


/// A still, moved. `background-position` transitions and CSS keyframes both leave the
/// frame static between steps; this drives the transform from requestAnimationFrame inside
/// the page so every frame differs, the same reason dwell() exists.
///
/// The illustration is NOT evidence and is never on screen long enough to be mistaken for
/// it. Nothing in these shots may imply an asset moving between chains: the PNG's right
/// half is release-or-refund on Arc, not a transfer, and the narration says so.
const ASSETS = path.join(repo, "dashboard", "video", "assets");
const uriCache = new Map();
function dataUri(file) {
  if (uriCache.has(file)) return uriCache.get(file);
  const ext = path.extname(file).slice(1);
  const mime = ext === "svg" ? "image/svg+xml" : `image/${ext}`;
  const u = `data:${mime};base64,${fs.readFileSync(path.join(ASSETS, file)).toString("base64")}`;
  uriCache.set(file, u);
  return u;
}

/// `captionAt` is milliseconds into the pan, not after it. The first version showed the
/// caption only once the animation had finished, so every still ran for its pan PLUS its
/// caption — nine seconds became eighteen, the film came out at 4:07 against a four-minute
/// ceiling, and the opening was nine seconds of a moving picture with nothing said over it.
// A held frame that keeps repainting. A truly static page produces one distinct frame
// per shot and the motion check reads that as a stall, so the hold breathes by a
// fraction of a percent — invisible to a viewer, visible to the encoder.
async function holdStill(file, at, ms, opts = {}) {
  await panStill(file, at, { s: at.s * 1.012, x: at.x, y: at.y }, ms, null, 900, opts);
}

// A lower third. The film had two registers — a full-screen card, or a bare screen — so a
// sentence and the thing it describes could never be on screen at once. That is affordable
// when the words are chapter titles; it is not affordable in a cold open, where the viewer
// needs to be told what they are looking at WHILE they look at it.
//
// Fire-and-forget by design: it returns as soon as the band is on screen, so the caller can
// go on driving the page underneath it. The body is guarded rather than `.catch()`-ed,
// because puppeteer's send() throws SYNCHRONOUSLY when a session is gone and a bare catch
// never sees it — that defect killed three takes before it was found.
function lower(html, ms = 4200, { near = null } = {}) {
  const inject = () => {
    try {
      page.evaluate((h, sel) => {
        document.getElementById("__lower")?.remove();
        const d = document.createElement("div");
        d.id = "__lower";
        d.innerHTML = `<div id="__lowertx">${h}</div>`;
        Object.assign(d.style, { position: "fixed", inset: "0", zIndex: "99998",
                                 pointerEvents: "none", opacity: "0",
                                 transition: "opacity .5s ease" });
        document.body.appendChild(d);
        const tx = d.querySelector("#__lowertx");
        Object.assign(tx.style, {
          position: "fixed", color: "#f2ede6", textWrap: "balance",
          background: "rgba(10,9,8,.94)", borderRadius: "12px",
          borderLeft: "4px solid #3fb950", padding: "20px 26px",
          boxShadow: "0 18px 48px rgba(0,0,0,.55)",
          font: "600 34px/1.32 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif",
          letterSpacing: "-.012em",
        });
        // Anchored UNDER the thing it describes. Fixed at the page's bottom-left, the caption
        // sat 450-530 px below the line that was changing — on a 1080 frame that is beyond
        // what one pair of eyes can hold at once, so a viewer read the words OR watched the
        // log and missed whichever they were not looking at. In a cold open that is the
        // whole shot. Now it shares the x-range of its subject and sits just beneath it.
        const el = sel && document.querySelector(sel);
        if (el) {
          const r = el.getBoundingClientRect();
          const width = Math.max(560, Math.min(r.width, window.innerWidth * 0.72));
          tx.style.left = Math.round(Math.max(24, r.left)) + "px";
          tx.style.width = Math.round(width) + "px";
          tx.style.top = Math.round(r.bottom + 22) + "px";
          // If the anchor sits low enough that the card would fall off the frame, put it
          // ABOVE instead. Off-screen is worse than unconventional.
          if (r.bottom + 22 + 180 > window.innerHeight) {
            tx.style.top = "";
            tx.style.bottom = (window.innerHeight - r.top + 22) + "px";
          }
        } else {
          tx.style.left = "6%"; tx.style.right = "6%"; tx.style.bottom = "7.5%";
        }
        for (const e of tx.querySelectorAll("i")) {
          Object.assign(e.style, { display: "block", fontStyle: "normal", color: "#3fb950",
                                   fontSize: "27px", fontWeight: "600", marginTop: "9px" });
        }
        requestAnimationFrame(() => { d.style.opacity = "1"; });
      }, html, near).catch(() => {});
    } catch {}
  };
  const drop = () => {
    try {
      page.evaluate(() => {
        const d = document.getElementById("__lower");
        if (!d) return;
        d.style.opacity = "0";
        setTimeout(() => d.remove(), 600);
      }).catch(() => {});
    } catch {}
  };
  inject();
  setTimeout(drop, ms);
}


// A deck slide, shown full-frame. The slides are built at exactly 1920x1080 by
// dashboard/video/build-deck.mjs from dashboard/deck/deck.html, so a slide IS a frame and
// nothing is scaled or letterboxed. Using them here rather than re-typing their words is
// the point: the film and the PDF cannot say different things because one file says both.
//
// It breathes by 1.5% over the hold. A slide that is byte-identical for eight seconds is a
// stalled video to anyone watching and a duplicate frame to motion.py, and neither is what
// a held title should look like.
const deckDir = path.join(repo, "dashboard", "media", "deck");
const slideCache = new Map();
function slideUri(n) {
  const key = String(n).padStart(2, "0");
  if (slideCache.has(key)) return slideCache.get(key);
  const f = path.join(deckDir, `slide-${key}.png`);
  if (!fs.existsSync(f)) {
    throw new Error(`slide ${key} is missing — run \`node dashboard/video/build-deck.mjs\` first`);
  }
  const u = `data:image/png;base64,${fs.readFileSync(f).toString("base64")}`;
  slideCache.set(key, u);
  return u;
}

// Deck chrome, drawn ON TOP of the live page. The film used to run three visual registers —
// screen recording, deck slide, and a black card with green type — and the last two were
// close enough in palette to the first that a viewer could not tell a CLAIM from EVIDENCE by
// looking. The black cards are gone entirely; what is left is the deck, and the live page
// wearing the deck's frame. Same typography, same rule, same margins, so a cut between them
// is a change of content rather than a change of world.
//
// It is an overlay, not an iframe. Driving the demo through a frame would mean rewriting
// every selector in this file, and a rewrite of working interaction code to gain a border is
// a bad trade.
async function chrome(kicker, n = "") {
  if (!CARDS) return;
  await page.evaluate((k, num) => {
    document.getElementById("__chrome")?.remove();
    const d = document.createElement("div");
    d.id = "__chrome";
    d.innerHTML = `<div id="__ck"></div><div id="__cn"></div><div id="__cr"></div><div id="__cb"></div>`;
    Object.assign(d.style, { position: "fixed", inset: "0", zIndex: "99990",
                             pointerEvents: "none", opacity: "0",
                             transition: "opacity .5s ease" });
    document.body.appendChild(d);
    const F = "600 26px/1 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif";
    // A band at the very top and the very bottom, in the deck's ink, so the browser page
    // sits INSIDE a frame instead of being the whole frame.
    Object.assign(d.querySelector("#__cb").style, {
      position: "fixed", left: "0", right: "0", top: "0", height: "104px",
      background: "linear-gradient(to bottom, #17130f 62%, rgba(23,19,15,0))" });
    Object.assign(d.querySelector("#__ck").style, {
      position: "fixed", left: "60px", top: "34px", font: F, letterSpacing: ".18em",
      textTransform: "uppercase", color: "#8a7f72", zIndex: "1" });
    Object.assign(d.querySelector("#__cn").style, {
      position: "fixed", right: "60px", top: "34px", zIndex: "1",
      font: "600 26px/1 ui-monospace,SFMono-Regular,Menlo,monospace", color: "#8a7f72" });
    Object.assign(d.querySelector("#__cr").style, {
      position: "fixed", left: "0", right: "0", bottom: "0", height: "6px",
      background: "#17130f", borderTop: "2px solid #3fb950" });
    d.querySelector("#__ck").textContent = k;
    d.querySelector("#__cn").textContent = num;
    requestAnimationFrame(() => { d.style.opacity = "1"; });
  }, kicker, n).catch(() => {});
}


async function deckSlide(n, ms, { navigate = null, during = null, label = "" } = {}) {
  if (!CARDS) {
    await sleep(ms);
    if (navigate) { await page.goto(navigate, { waitUntil: "domcontentloaded" }); await cursor(); }
    if (during) await during();
    return;
  }
  const uri = slideUri(n);
  beat(`SLIDE ${String(n).padStart(2, "0")}${label ? " " + label : ""}`);
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    html,body{margin:0;height:100%;background:#17130f;overflow:hidden}
    img{position:fixed;inset:0;width:100%;height:100%;object-fit:cover;
        transform:scale(1);transition:transform ${ms}ms linear;
        opacity:0;transition:transform ${ms}ms linear, opacity .55s ease}
  </style><img id="s" src="${uri}">`);
  await sleep(120);
  await page.evaluate(() => {
    const e = document.getElementById("s");
    if (e) { e.style.opacity = "1"; e.style.transform = "scale(1.015)"; }
  });
  await sleep(Math.max(600, ms - 600));
  await page.evaluate(() => { const e = document.getElementById("s"); if (e) e.style.opacity = "0"; });
  await sleep(450);
  if (navigate) {
    await page.goto(navigate, { waitUntil: "domcontentloaded" });
    await page.waitForNetworkIdle({ idleTime: 400, timeout: 30000 }).catch(() => {});
    await cursor();
  }
  if (during) await during();
}


async function panStill(file, from, to, ms, caption = null, captionAt = 900, opts = {}) {
  // Matted by default: the picture sits in a smaller frame on a near-black surround and
  // the caption goes in the dark below it, the way a documentary treats a still. Full-bleed
  // put type over the busiest part of the illustration and needed a scrim to stay legible,
  // which then dimmed the picture it was printed on. A mat costs picture area and buys
  // a caption that is never fighting the image for the same pixels.
  //
  // `mat: false` is for the SVG diagram. That asset is designed to be read edge to edge
  // — its scope disclosure is 20px type at the bottom margin — and shrinking it to 76%
  // would trade away exactly the legibility the mat exists to protect.
  const mat = opts.mat !== false;
  const uri = dataUri(file);
  await page.setContent(`<!doctype html><meta charset="utf-8"><style>
    html,body{margin:0;height:100%;background:#080706;overflow:hidden}
    #f{position:fixed;overflow:hidden;
       ${mat ? "left:11%;right:11%;top:6.5%;height:60%;box-shadow:0 24px 80px rgba(0,0,0,.75);"
             : "inset:0;"}}
    #i{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;
       transform-origin:50% 50%;will-change:transform}
    ${mat ? "" : `#scrim{position:fixed;left:0;right:0;bottom:0;height:42%;pointer-events:none;
       background:linear-gradient(to top, rgba(8,7,6,.92) 0%, rgba(8,7,6,.72) 38%,
                  rgba(8,7,6,0) 100%);opacity:0;transition:opacity .8s ease}`}
    #cap{position:fixed;opacity:0;transition:opacity .8s ease;
         text-wrap:balance;hyphens:none;
         ${mat ? "left:11%;right:11%;top:71.5%;" : "left:6%;right:6%;bottom:8%;"}
         font:400 30px/1.45 ui-sans-serif,-apple-system,'SF Pro Display',Inter,sans-serif;
         color:#e9e3da}
    #cap b{display:block;font:700 60px/1.05 ui-sans-serif,-apple-system,Inter,sans-serif;
           letter-spacing:-.025em;margin-bottom:14px;color:#f7f3ec}
    #cap i{display:block;font-style:normal;color:#3fb950;font-size:28px;margin-top:11px;
           font-weight:600}
  </style>
  <div id="f"><img id="i" src="${uri}"></div>
  ${caption ? `${mat ? "" : '<div id="scrim"></div>'}<div id="cap">${caption}</div>` : ""}`);
  // `.catch()` alone is not enough here: when the session is gone puppeteer's send()
  // THROWS synchronously, so no promise ever exists to attach a catch to, and the throw
  // escaped the timer as an uncaughtException that killed the whole take. Guard the body,
  // and cancel anything still pending when the shot ends.
  const fade = (to) => {
    try {
      page.evaluate((o) => {
        for (const id of ["scrim", "cap"]) {
          const e = document.getElementById(id); if (e) e.style.opacity = o;
        }
      }, to).catch(() => {});
    } catch {}
  };
  const timers = [];
  if (caption) {
    timers.push(setTimeout(() => fade("1"), captionAt));
    timers.push(setTimeout(() => fade("0"), Math.max(captionAt + 1500, ms - 700)));
  }
  await page.evaluate(({ from, to, dur }) => {
    const el = document.getElementById("i");
    const set = (s, x, y) => { el.style.transform = `scale(${s}) translate(${x}%, ${y}%)`; };
    set(from.s, from.x, from.y);
    return new Promise((done) => {
      const t0 = performance.now();
      const step = (t) => {
        const k = Math.min(1, (t - t0) / dur);
        const e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
        set(from.s + (to.s - from.s) * e,
            from.x + (to.x - from.x) * e,
            from.y + (to.y - from.y) * e);
        k < 1 ? requestAnimationFrame(step) : done();
      };
      requestAnimationFrame(step);
    });
  }, { from, to, dur: ms });
  timers.forEach(clearTimeout);
}

async function showCaption(ms = 0) {
  await page.evaluate(() => { for (const id of ["scrim", "cap"]) { const e = document.getElementById(id); if (e) e.style.opacity = "1"; } });
  if (ms) await sleep(ms);
}
async function hideCaption() {
  await page.evaluate(() => { for (const id of ["scrim", "cap"]) { const e = document.getElementById(id); if (e) e.style.opacity = "0"; } });
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
// The page is loaded BEFORE the camera rolls. A cold open that begins on a blank tab and
// then settles is not a cold open; it is a page load a viewer has to sit through. Measured
// on the first take: 1.5 s of a frozen frame, then a caption, then two more seconds of
// stillness before the first click. Frame zero now shows the escrow already on screen.
await page.goto(BASE + "/arc.html", { waitUntil: "domcontentloaded" });
await page.waitForNetworkIdle({ idleTime: 400, timeout: 30000 }).catch(() => {});
await page.evaluate(() => window.scrollTo(0, 0));
await cursor();
await chrome("Try to steal it", "00");
await sleep(600);

await rec.start(RAW(out));
t0 = Date.now();

// ---- the film, rebuilt from zero on one question --------------------------------
// What does a judge do? Watches forty of these at 1.5x and decides in twenty seconds whether
// the project is real. An explainer competes with all forty. What this project has that
// almost none of them do is that the judge can CHECK IT THEMSELVES, right now, with nothing
// installed — so the film's job is not to explain Reckn. It is to turn a viewer into a
// verifier.
//
// Hence: four checks, announced as checks. The honesty section is check FOUR rather than a
// caveat at the end, because "here is what we do not prove" is the rarest thing in a
// hackathon video and burying it wastes the only claim nobody else is making.

await openingPlate(BASE + "/arc.html");

// The offer. Everything after this is the viewer checking it.
await deckSlide(2, 7500, { label: "the claim, and the offer" });

// ---- check 1 · a real proof that cannot take the money ---------------------------
await deckSlide(3, 6500, { label: "check 1", navigate: BASE + "/arc.html" });
await chrome("Check 1 · try to steal it", "01");
await page.evaluate(() => window.scrollTo(0, 0));
await sleep(400);

beat("01 fund");
lower("A funded deal. 250.00 USDC.<i>Nobody has a key to it.</i>", 5200, { near: ".acct, #log" });
await press('button[data-act="fund"][data-deal="honest"]', "tx 0x", { hold: 4800 });
await page.evaluate(() => document.getElementById("log")?.scrollIntoView({ behavior: "smooth", block: "center" }));
await sleep(500);
beat("01 BindingMismatch");
lower("A <b>real</b> Groth16 proof. It verifies.<i>It is a proof of a different execution.</i>", 6400, { near: "#log" });
await press('button[data-act="settle"][data-proof="decrease"]', "BindingMismatch", { hold: 6600 });
lower("<b>The money did not move.</b><i>Valid was not enough. It had to be about THIS deal.</i>", 5200, { near: "#log" });
await sleep(5400);
beat("02 evidence: release");
lower("The proof this deal was funded against. It reproduces.<i>Released to the seller.</i>", 5200, { near: "#log" });
await press('button[data-act="settle"][data-deal="honest"]:not([data-proof])', "tx 0x", { hold: 5200 });
beat("02 evidence: refund");
lower("Now a delivery that did <b>not</b> reproduce.<i>The same machinery refunds the buyer.</i>", 6600, { near: "#log" });
await press('button[data-act="fund"][data-deal="decrease"]', "tx 0x", { hold: 1200 });
await press('button[data-act="settle"][data-deal="decrease"]', "tx 0x", { hold: 5200 });

// ---- check 2 · the code, verified in the viewer's own browser --------------------
await deckSlide(4, 6500, { label: "check 2", navigate: LIVE + "/" });
await chrome("Check 2 · the code that holds it", "02");
beat("02 evidence: bytecode + no-keys");
await page.waitForFunction(
  () => document.querySelector("#s-code")?.textContent === "\u2713",
  { timeout: 60000 },
).catch(() => { throw new Error("the live page's bytecode check did not go green"); });
// Trimmed against beats.tsv, not against a feeling. This block measured 27.8 s and the
// second half of it was a still page — `motion` read it as 8/8 because a cursor moved,
// which is why that check never caught it. It measures pixels changing, not the argument
// advancing, and those are different properties.
await sleep(1200);
await dwell("#d-code", 4000);

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
  await sleep(1100);
  for (let k = 0; k < groups.length; k++) {
    await page.evaluate((id) => { const e = document.getElementById(id); if (e) e.style.opacity = "1"; }, `g${k}`);
    await sleep(620);
  }
  await page.evaluate(() => { const e = document.getElementById("v"); if (e) e.style.opacity = "1"; });
  await sleep(2600);
}

// ---- check 3 · real settlements, two of them decided on Solana -------------------
await deckSlide(5, 7000, { label: "check 3", navigate: LIVE + "/" });
await chrome("Check 3 · real money, another chain", "03");
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
  await dwell("#rows", 11000);
}

await deckSlide(6, 6000, { label: "the boundary" });
beat("17 SVG: out to Arc, scope held");
await panStill("solana-proof-to-arc-settlement.svg",
  { s: 1.06, x: 1, y: 1 }, { s: 1.0, x: 0, y: 0 }, 5000, null, 900, { mat: false });
await holdStill("solana-proof-to-arc-settlement.svg", { s: 1.0, x: 0, y: 0 }, 3500, { mat: false });
await sleep(500);

// ---- check 4 · the one nobody else shows you ------------------------------------
await deckSlide(7, 9500, {
  label: "check 4 - what it does not prove",
  navigate: LIVE + "/",
  during: () => page.evaluate(() => document.querySelector("table.two")
    ?.scrollIntoView({ block: "center" })),
});
await chrome("Check 4 · what it does not prove", "04");
beat("06 evidence: the two rows");
await dwell("table.two", 11000);

// ---- the URL, big, and nothing after it -----------------------------------------
await deckSlide(8, 9000, { label: "check it yourself" });
// The door's last line still has to land, and the closing plate that used to carry it is
// gone — the URL slide ends the film now. One short plate, door-specific, after it.
await closingPlate(6000);

beat("END");
await rec.stop();
fs.writeFileSync(path.join(repo, "dashboard", "video", CARDS ? `beats-v3${SUF}.tsv` : `beats-v3${SUF}-clean.tsv`),
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
