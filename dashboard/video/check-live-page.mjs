// Loads a generated live page in a real browser and reports every status marker it sets.
//
// A page that says "your browser reads this from the chain" is a claim about something that
// only happens in a browser, so checking it by reading the HTML proves nothing. This opens
// it, waits for the network to settle, and prints every `s-*` / `t-*` element plus any page
// error — so "all five checks go green" is measured rather than asserted.
//
//   cd docs && python3 -m http.server 8901 &
//   node dashboard/video/check-live-page.mjs http://127.0.0.1:8901/tempo.html [out.png]
//
// It lives here because this is where puppeteer is installed.
import puppeteer from "puppeteer";
const url = process.argv[2], shot = process.argv[3];
const b = await puppeteer.launch({ headless: "new", args: ["--window-size=1400,2400"] });
const p = await b.newPage();
await p.setViewport({ width: 1400, height: 2400, deviceScaleFactor: 1 });
const errs = [];
p.on("pageerror", (e) => errs.push("pageerror: " + e.message));
p.on("console", (m) => { if (m.type() === "error") errs.push("console: " + m.text()); });
await p.goto(url, { waitUntil: "networkidle0", timeout: 60000 });
await new Promise(r => setTimeout(r, 4000));
const st = await p.evaluate(() => {
  const out = {};
  for (const e of document.querySelectorAll("[id^='s-']")) out[e.id] = e.textContent.trim() + " " + e.className;
  for (const e of document.querySelectorAll("[id^='t-']")) out[e.id] = e.textContent.trim().slice(0, 80);
  out["_rows_pre"] = document.querySelectorAll("#rows-pre tr").length;
  out["_rows_fee"] = document.querySelectorAll("#rows-fee tr").length;
  out["_v-tokname"] = document.getElementById("v-tokname").textContent.trim();
  out["_v-right"] = document.getElementById("v-right").textContent.trim();
  out["_v-wrong"] = document.getElementById("v-wrong").textContent.trim();
  out["_d-fee"] = document.getElementById("d-fee").textContent.trim().slice(0, 120);
  return out;
});
console.log(JSON.stringify(st, null, 1));
console.log("page errors:", errs.length ? errs : "none");
if (shot) await p.screenshot({ path: shot, fullPage: true });
await b.close();
