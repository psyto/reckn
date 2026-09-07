// Preview one matted still WITHOUT re-recording four minutes. The markup is sliced out of
// record.js at run time rather than retyped, so the preview cannot drift from the film.
import fs from "node:fs";
import puppeteer from "puppeteer-core";
const repo = "/Users/hiroyusai/src/reckn";
const src = fs.readFileSync(repo + "/dashboard/video/record.js", "utf8");
// Anchored INSIDE panStill: card() and the two plates open with the same doctype line,
// so an unanchored search sliced from the first of them and produced a fragment
// spanning three functions.
const fn   = src.indexOf("async function panStill(");
const from = src.indexOf("`<!doctype html><meta charset=\"utf-8\"><style>", fn);
const to   = src.indexOf("\n", src.indexOf("${caption ?", from));
const tpl  = src.slice(from, to).replace(/\)\s*;\s*$/, "").trimEnd();
const file = "proof-gated-escrow-storyboard-v1.png";
const b = fs.readFileSync(`${repo}/dashboard/video/assets/${file}`);
const uri = `data:image/png;base64,${b.toString("base64")}`;
const caption = process.env.CAP === "0" ? null : "<b>Reckn</b>Agent-payment escrow where a disputed delivery is re-executed, not judged."
              + "<i>Reproduce, or refund.</i>";
const mat = true;
const html = eval(tpl);
const browser = await puppeteer.launch({
  executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  headless: "new", args: ["--window-size=1920,1080", "--hide-scrollbars"],
});
const page = await browser.newPage();
await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
await page.setContent(html);
await page.evaluate((tx) => {
  document.getElementById("i").style.transform = tx;
  for (const id of ["scrim", "cap"]) { const e = document.getElementById(id); if (e) { e.style.transition = "none"; e.style.opacity = "1"; } }
}, process.env.TX || "scale(2.35) translate(27%, 7%)");
await new Promise(r => setTimeout(r, 600));
await page.screenshot({ path: process.argv[2] });
await browser.close();
