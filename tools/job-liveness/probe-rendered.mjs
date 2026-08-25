// Manual probe: confirms the rendered checker separates a live Google Careers requisition
// from a pulled one, which a status-code or raw-fetch check cannot. Not part of `npm test`
// - it hits the network. Run: node probe-rendered.mjs <url> [<url> ...]
import { parsePostings } from "./check.mjs";

const { chromium } = await import("playwright").catch(() =>
  import(new URL("../../../job-applications/node_modules/playwright/index.mjs", import.meta.url).href)
);
const browser = await chromium.launch({ headless: true });
for (const url of process.argv.slice(2)) {
  const page = await browser.newPage();
  const res = await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
  await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => {});
  const body = (await page.evaluate(() => document.body.innerText)).trim();
  console.log(`\n${url}\n  HTTP ${res.status()}  rendered ${body.length} chars\n  ${JSON.stringify(body.slice(0, 220))}`);
  await page.close();
}
await browser.close();
void parsePostings;
