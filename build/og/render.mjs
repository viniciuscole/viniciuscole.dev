import { chromium } from "playwright";
import { pathToFileURL } from "node:url";
import { join } from "node:path";

const root = process.argv[2];
const card = pathToFileURL(join(root, "build/og/card.html")).href;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });

for (const locale of ["en", "pt"]) {
  await page.goto(`${card}?${locale}`);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: join(root, `src/images/og/card.${locale}.png`) });
}

await browser.close();
