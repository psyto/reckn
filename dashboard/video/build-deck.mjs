// Builds the pitch deck's three outputs from ONE source, dashboard/deck/deck.html:
//
//   docs/deck.html                     a page anyone can open, SVG inlined so it is standalone
//   dashboard/media/reckn-deck.pdf     the file a sponsor or a residency asks for
//   dashboard/media/deck/slide-NN.png  1920x1080 stills the film cuts to
//
// One source, because a deck and a film that state the same claim from two files will state
// it two ways eventually. This repository has watched a single video's running time drift
// into three different numbers across three documents; positioning drifts the same way and
// is harder to notice.
//
//   node dashboard/video/build-deck.mjs
//
// It lives in dashboard/video/ rather than beside deck.html because that is where puppeteer
// is installed and node resolves imports from the SCRIPT's directory, not the shell's.
// preview.mjs and check-live-page.mjs are here for the same reason.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import puppeteer from "puppeteer";

const dir = path.dirname(fileURLToPath(import.meta.url));
const repo = path.join(dir, "..", "..");
const W = 1920, H = 1080;

// The boundary diagram is inlined rather than linked, so docs/deck.html and the PDF are
// self-contained. It is the SAME file the film pans over — one asset, not a copy that can
// fall behind.
const svgPath = path.join(repo, "dashboard/video/assets/solana-proof-to-arc-settlement.svg");
const svg = `data:image/svg+xml;base64,${fs.readFileSync(svgPath).toString("base64")}`;
const src = fs.readFileSync(path.join(repo, "dashboard/deck/deck.html"), "utf8");
if (!src.includes("/*__SVG__*/")) throw new Error("deck.html lost its /*__SVG__*/ placeholder");
const html = src.replace("/*__SVG__*/", svg);

const outHtml = path.join(repo, "docs/deck.html");
fs.writeFileSync(outHtml, html);

const browser = await puppeteer.launch({
  headless: "new",
  args: ["--force-color-profile=srgb", "--hide-scrollbars"],
});
const page = await browser.newPage();
await page.setViewport({ width: W, height: H, deviceScaleFactor: 1 });
const errs = [];
page.on("pageerror", (e) => errs.push(e.message));
await page.goto("file://" + outHtml, { waitUntil: "networkidle0" });

const ids = await page.$$eval("section.slide", (ss) => ss.map((s) => s.id));
if (ids.length < 5) throw new Error(`only ${ids.length} slides found — deck.html is not what it should be`);

// Every slide must be EXACTLY one frame. A deck whose slides are 1080.5 px tall produces
// stills the film has to letterbox, and a PDF with a hairline of the next page at the
// bottom of every sheet.
const sizes = await page.$$eval("section.slide", (ss) =>
  ss.map((s) => [s.id, Math.round(s.getBoundingClientRect().width), Math.round(s.getBoundingClientRect().height)]));
const wrong = sizes.filter(([, w, h]) => w !== 1920 || h !== 1080);
if (wrong.length) {
  throw new Error("slides are not 1920x1080: " + wrong.map(([i, w, h]) => `${i} ${w}x${h}`).join(", "));
}

// Overflow is the other silent failure: text that runs past the slide is invisible in the
// PDF and cropped in the still, and nothing about the page looks wrong while it happens.
const overflow = await page.$$eval("section.slide", (ss) =>
  ss.filter((s) => s.scrollHeight > s.clientHeight + 2 || s.scrollWidth > s.clientWidth + 2)
    .map((s) => `${s.id} (${s.scrollWidth}x${s.scrollHeight})`));
if (overflow.length) throw new Error("content overflows: " + overflow.join(", "));

const shotDir = path.join(repo, "dashboard/media/deck");
fs.mkdirSync(shotDir, { recursive: true });
for (const [i, id] of ids.entries()) {
  const el = await page.$("#" + id);
  const out = path.join(shotDir, `slide-${String(i + 1).padStart(2, "0")}.png`);
  await el.screenshot({ path: out });
}

// Where each slide's reveal bands start, measured from the rendered page rather than
// guessed. The film uncovers a slide from the top down at these y positions, so the reader
// is led through the same order the layout already implies.
const steps = {};
for (const [i, id] of ids.entries()) {
  // Relative to the SECTION, not the viewport. Measured viewport-relative first, and every
  // slide but one came back empty: el.screenshot() scrolls each section into view, so by the
  // time this loop ran the page sat at the last slide and every other rect was negative.
  const ys = await page.$eval(`#${id}`, (sec) => {
    const top = sec.getBoundingClientRect().top;
    return [...sec.querySelectorAll(".step")]
      .map((e) => Math.round(e.getBoundingClientRect().top - top))
      .filter((y) => y > 40 && y < 1040)
      .sort((a, b) => a - b);
  });
  // The first band starts at the FIRST element, so the slide opens blank and fills in.
  const uniq = [...new Set(ys)].slice(0, 5);
  steps[String(i + 1).padStart(2, "0")] = uniq;
}
// And how many words each slide asks a viewer to read. A slide's on-screen time is derived
// from this rather than typed into the recorder: the first cut demanded 255-349 wpm where
// comfortable reading of display type is 150-180, and hardcoded seconds drift away from the
// copy the moment anyone edits a line. Now they cannot.
const wordsPerSlide = {};
for (const [i, id] of ids.entries()) {
  wordsPerSlide[String(i + 1).padStart(2, "0")] = await page.$eval(`#${id}`, (sec) => {
    const c = sec.cloneNode(true);
    c.querySelector(".foot")?.remove();          // the footer is fine print, not reading load
    return (c.textContent || "").trim().split(/\s+/).filter(Boolean).length;
  });
}
fs.writeFileSync(path.join(shotDir, "steps.json"),
  JSON.stringify({ bands: steps, words: wordsPerSlide }, null, 1));

const pdf = path.join(repo, "dashboard/media/reckn-deck.pdf");
await page.pdf({ path: pdf, width: `${W}px`, height: `${H}px`, printBackground: true, pageRanges: `1-${ids.length}` });
await browser.close();

if (errs.length) throw new Error("the deck threw in the page: " + errs.join(" | "));

const kb = (p) => (fs.statSync(p).size / 1024).toFixed(0);
console.log(`✓ ${ids.length} slides, all 1920x1080, none overflowing`);
console.log(`  docs/deck.html                    ${kb(outHtml)} KB`);
console.log(`  dashboard/media/reckn-deck.pdf    ${kb(pdf)} KB`);
console.log(`  dashboard/media/deck/slide-NN.png ${ids.length} files`);
console.log(`  dashboard/media/deck/steps.json     ${Object.values(steps).reduce((a, b) => a + b.length, 0)} reveal bands`);
