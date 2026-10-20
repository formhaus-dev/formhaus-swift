import { existsSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { footage, frames, readJSON, script } from './paths.mjs';
import { locateTaps } from './taps.mjs';
import { resolveColor } from './tokens.mjs';

const config = script();
const manifestPath = join(footage, 'manifest.json');
const manifest = {};

const source = (id) => ['mov', 'png'].map((ext) => join(footage, `${id}.${ext}`)).find(existsSync);

const hex = (value) => [1, 3, 5].map((offset) => parseInt(value.slice(offset, offset + 2), 16));

const iosTaps = (file, start, timeline, spec) => {
  const primary = hex(resolveColor(config.theme.colors.primary));
  return locateTaps(file, start, timeline, spec.screen, primary);
};

const webTaps = (timeline) =>
  timeline.taps.map(({ time, kind, x, y }) => ({ time, kind, x: x / timeline.size[0], y: y / timeline.size[1] }));

const webPointer = (timeline) =>
  timeline.pointer.map((point) => point && [Number((point[0] / timeline.size[0]).toFixed(5)), Number((point[1] / timeline.size[1]).toFixed(5))]);

const nominalMarks = (timeline, nominal) =>
  timeline.marks.filter(({ name }) => name in nominal && name !== 'first').map(({ name, time }) => [nominal[name], Number(time.toFixed(3))]);

for (const [id, clip] of Object.entries(config.footage)) {
  if (config.devices[clip.device].kind === 'browser') {
    if (!existsSync(join(frames, id, 'info.json'))) continue;
    const timeline = readJSON(join(footage, `${id}.timeline.json`));
    manifest[id] = { file: id, frames: true, start: 0, marks: nominalMarks(timeline, config.marks[clip.script]), taps: webTaps(timeline), pointer: webPointer(timeline) };
    console.log(`${id}: ${timeline.pointer.length} frames, ${timeline.taps.length} taps`);
    continue;
  }
  const file = source(id);
  if (!file) continue;
  if (clip.still) {
    manifest[id] = { file: basename(file), still: true };
    continue;
  }
  const timeline = readJSON(join(footage, `${id}.timeline.json`));
  const nominal = config.marks[clip.script];
  const start = 0;
  const marks = nominalMarks(timeline, nominal);
  const taps = iosTaps(file, start, timeline, config.devices[clip.device]);
  manifest[id] = { file: basename(file), start: Number(start.toFixed(3)), marks, taps };
  console.log(`${id}: starts at ${start.toFixed(2)} s, ${taps.length} taps, drift ${marks.map(([a, b]) => (b - a).toFixed(2)).join(' ')}`);
}
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
