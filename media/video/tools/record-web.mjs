import { mkdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from 'playwright';
import { footage, script } from './paths.mjs';
import { serve } from './serve.mjs';

const primary = (page) => page.locator('.fh-form-actions__button--primary');

const actions = {
  tour: {
    error: ['next', primary],
    landing: ['pick', (page) => page.locator('.fh-field__radio-label', { hasText: 'A landing page' })],
    branch: ['next', primary],
    back: ['back', (page) => page.getByRole('button', { name: 'Back' })],
  },
  branch: {
    landing: ['pick', (page) => page.locator('.fh-field__radio-label', { hasText: 'A landing page' })],
    branch: ['next', primary],
  },
};

const tap = async (page, [kind, target], time) => {
  const box = await target(page).boundingBox();
  await target(page).click();
  return { time, kind, x: box.x + box.width / 2, y: box.y + box.height / 2 };
};

const wait = (ms) => new Promise((done) => setTimeout(done, Math.max(0, ms)));

const record = async (browser, origin, id, clip, config) => {
  const [width, height] = config.devices[clip.device].viewport;
  const scale = config.devices[clip.device].scale;
  const dir = join(footage, 'web-tmp', id);
  rmSync(dir, { recursive: true, force: true });
  const context = await browser.newContext({
    viewport: { width: width * scale, height: height * scale },
    deviceScaleFactor: 1,
    reducedMotion: 'no-preference',
    recordVideo: { dir, size: { width: width * scale, height: height * scale } },
  });
  const page = await context.newPage();
  await page.goto(`${origin}/web/dist/index.html?def=${clip.definition}&zoom=${scale}`);
  await page.waitForSelector('html[data-ready="true"]', { state: 'attached', timeout: 60000 });
  await page.waitForTimeout(200);
  await page.evaluate(() => document.fonts.ready);
  const start = Date.now();
  const elapsed = () => (Date.now() - start) / 1000;
  const timeline = { size: [width * scale, height * scale], marks: [], taps: [] };
  for (const [mark, time] of Object.entries(config.marks[clip.script])) {
    if (mark === clip.stop) break;
    const action = actions[clip.script][mark];
    if (!action) continue;
    await wait(time * 1000 - (Date.now() - start));
    timeline.marks.push({ name: mark, time: elapsed() });
    timeline.taps.push(await tap(page, action, elapsed()));
  }
  writeFileSync(join(footage, `${id}.timeline.json`), JSON.stringify(timeline));
  await wait(clip.length * 1000 - (Date.now() - start));
  const video = page.video();
  await context.close();
  renameSync(await video.path(), join(footage, `${id}.webm`));
  rmSync(dir, { recursive: true, force: true });
};

const config = script();
const only = process.argv.slice(2);
const clips = Object.entries(config.footage).filter(
  ([id, clip]) => config.devices[clip.device].kind === 'browser' && (only.length === 0 || only.includes(id)),
);
mkdirSync(footage, { recursive: true });
const server = await serve();
const browser = await chromium.launch({ headless: true });
try {
  for (const [id, clip] of clips) {
    await record(browser, server.origin, id, clip, config);
    console.log(`recorded ${id}`);
  }
} finally {
  await browser.close();
  await server.close();
  rmSync(join(footage, 'web-tmp'), { recursive: true, force: true });
}
