import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { chromium } from 'playwright';
import { easeInOut } from '../scenes/kit.js';
import { footage, frames, readJSON, repo, script } from './paths.mjs';
import { serve } from './serve.mjs';

const fps = 60;
const travel = 0.42;
const arrive = 0.06;
const primary = (page) => page.locator('.fh-form-actions__button--primary');
const option = (text) => (page) => page.locator('.fh-field__radio-label', { hasText: text });
const input = (key) => (page) => page.locator(`input[name="${key}"]`);

const actions = {
  branch: {
    landing: ['pick', option('Landing page')],
    branch: ['next', primary],
    errors: ['submit', primary],
    typing: ['fill', input('name'), 'Ada Lovelace'],
  },
};

const keystrokes = (text, timings, speed) => {
  let time = 0;
  return [...text].map((character, index) => {
    const at = time;
    time += (timings.keystroke + (' .@'.includes(character) ? timings.wordPause : 0)) / speed;
    return { at, value: text.slice(0, index + 1) };
  });
};

const flush = (page) =>
  page.evaluate(
    () =>
      new Promise((done) => {
        const channel = new MessageChannel();
        channel.port1.onmessage = () => {
          const again = new MessageChannel();
          again.port1.onmessage = () => done();
          again.port2.postMessage(0);
        };
        channel.port2.postMessage(0);
      }),
  );

const freezeAnimations = () => {
  const started = new Map();
  window.__seekAnimations = (now) => {
    for (const animation of document.getAnimations()) {
      if (!started.has(animation)) {
        started.set(animation, now);
        animation.pause();
      }
      const local = now - started.get(animation);
      const end = animation.effect?.getComputedTiming().endTime ?? 0;
      if (local >= end) animation.finish();
      else animation.currentTime = local;
    }
  };
};

const setValue = (element, value) => {
  const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  setter.call(element, value);
  element.dispatchEvent(new Event('input', { bubbles: true }));
};

const center = async (locator) => {
  const box = await locator.boundingBox();
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
};

const record = async (browser, origin, id, clip, config) => {
  const [width, height] = config.devices[clip.device].viewport;
  const { scale } = config.devices[clip.device];
  const dir = join(frames, id);
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: scale, reducedMotion: 'no-preference' });
  const page = await context.newPage();
  await page.clock.install({ time: new Date('2026-10-20T09:41:00Z') });
  await page.addInitScript(freezeAnimations);
  await page.goto(`${origin}/web/dist/index.html?def=${clip.definition}`);
  await page.waitForSelector('html[data-ready="true"]', { state: 'attached', timeout: 60000 });
  await page.evaluate(() => document.fonts.ready);
  await flush(page);

  const speed = clip.speed ?? 1;
  const timings = readJSON(join(repo, 'Examples/FormhausDemo/FormhausDemo/Resources/demo-timings.json'));
  const steps = Object.entries(config.marks[clip.script])
    .filter(([mark]) => mark !== 'first')
    .sort(([, a], [, b]) => a - b);
  const stop = clip.stop ? config.marks[clip.script][clip.stop] : Infinity;
  const due = steps.filter(([mark, time]) => actions[clip.script][mark] && time < stop).map(([mark, time]) => ({ mark, time, action: actions[clip.script][mark] }));
  const timeline = { size: [width, height], offset: 0, marks: [], taps: [], pointer: [] };
  const total = Math.round(clip.length * fps);
  const typing = [];
  let pointer = null;
  let from = null;
  let next = 0;
  let target = null;

  for (let frame = 0; frame < total; frame += 1) {
    const time = frame / fps;
    const upcoming = due[next];
    if (upcoming && !target && time >= upcoming.time - travel - arrive) {
      target = await center(upcoming.action[1](page));
      pointer ??= { x: target.x + 150, y: target.y + 110 };
      from = { ...pointer, at: time };
    }
    if (target) {
      const move = easeInOut(Math.min(1, (time - from.at) / travel));
      pointer = { x: from.x + (target.x - from.x) * move, y: from.y + (target.y - from.y) * move };
    }
    if (pointer) await page.mouse.move(pointer.x, pointer.y);
    if (upcoming && time >= upcoming.time) {
      const [kind, locate, text] = upcoming.action;
      timeline.marks.push({ name: upcoming.mark, time });
      timeline.taps.push({ time, kind: kind === 'fill' ? 'type' : kind, x: target.x, y: target.y });
      if (kind === 'fill') {
        const handle = await locate(page).elementHandle();
        typing.push(...keystrokes(text, timings, speed).map((key) => ({ ...key, at: time + key.at, handle })));
      } else {
        await page.mouse.click(target.x, target.y);
      }
      next += 1;
      target = null;
    }
    while (typing.length && time >= typing[0].at) {
      const key = typing.shift();
      await key.handle.evaluate(setValue, key.value);
    }
    if (frame > 0) await page.clock.runFor(Math.round((frame * 1000) / fps) - Math.round(((frame - 1) * 1000) / fps));
    await flush(page);
    await page.evaluate((now) => window.__seekAnimations(now), time * 1000);
    timeline.pointer.push(pointer ? [Number(pointer.x.toFixed(2)), Number(pointer.y.toFixed(2))] : null);
    await page.screenshot({ path: join(dir, `${String(frame + 1).padStart(5, '0')}.png`), type: 'png' });
  }
  writeFileSync(join(footage, `${id}.timeline.json`), JSON.stringify(timeline));
  writeFileSync(join(dir, 'info.json'), JSON.stringify({ start: 0, rate: fps, count: total, still: false, ext: 'png' }));
  await context.close();
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
    const begin = Date.now();
    await record(browser, server.origin, id, clip, config);
    console.log(`recorded ${id} in ${((Date.now() - begin) / 1000).toFixed(0)} s`);
  }
} finally {
  await browser.close();
  await server.close();
}
