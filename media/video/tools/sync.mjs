import { spawnSync } from 'node:child_process';
import { existsSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { footage, readJSON, script } from './paths.mjs';
import { locateTaps } from './taps.mjs';
import { resolveColor } from './tokens.mjs';

const config = script();
const manifestPath = join(footage, 'manifest.json');
const manifest = {};

const source = (id) => ['mov', 'webm', 'png'].map((ext) => join(footage, `${id}.${ext}`)).find(existsSync);

const samples = (file) => {
  const { stdout } = spawnSync(
    'ffmpeg',
    ['-hide_banner', '-nostats', '-fflags', '+igndts', '-i', file, '-vf', "scale=120:-2,signalstats,select='gte(scene,0)',metadata=print:file=-", '-f', 'null', '-'],
    { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 },
  );
  return stdout
    .split(/^frame:/m)
    .map((block) => [block.match(/pts_time:([\d.]+)/), block.match(/YAVG=([\d.]+)/), block.match(/scene_score=([\d.]+)/)])
    .filter((matches) => matches.every(Boolean))
    .map(([time, luma, score]) => ({ time: Number(time[1]), luma: Number(luma[1]), score: Number(score[1]) }));
};

const firstEvent = (frames) => {
  const launch = frames.find((frame) => frame.luma > 225);
  const changes = frames.filter((frame) => launch && frame.time > launch.time && frame.score > 0.02);
  const event = changes.find((frame, index) => frame.time - (changes[index - 1]?.time ?? launch.time) >= 0.4);
  if (!event) throw new Error('No first event found');
  return event.time;
};

const refine = (frames, start, timeline) => {
  const deltas = timeline.taps
    .filter((tap) => ['next', 'pick', 'submit'].includes(tap.kind))
    .map((tap) => {
      const frame = frames.find((item) => item.score > 0.004 && item.time - start - tap.time > -0.3 && item.time - start - tap.time < 0.6);
      return frame && frame.time - start - tap.time;
    })
    .filter((delta) => delta !== undefined)
    .sort((a, b) => a - b);
  return deltas.length ? start + deltas[Math.floor(deltas.length / 2)] : start;
};

const hex = (value) => [1, 3, 5].map((offset) => parseInt(value.slice(offset, offset + 2), 16));

const iosTaps = (file, start, timeline, spec) => {
  const primary = hex(resolveColor(config.theme.colors.primary));
  return locateTaps(file, start, timeline, spec.screen, primary);
};

const webTaps = (timeline) =>
  timeline.taps.map(({ time, kind, x, y }) => ({ time, kind, x: x / timeline.size[0], y: y / timeline.size[1] }));

for (const [id, clip] of Object.entries(config.footage)) {
  const file = source(id);
  if (!file) continue;
  if (clip.still) {
    manifest[id] = { file: basename(file), still: true };
    continue;
  }
  const timeline = readJSON(join(footage, `${id}.timeline.json`));
  const nominal = config.marks[clip.script];
  const frames = samples(file);
  const first = firstEvent(frames) - timeline.taps[0].time;
  const start = Math.max(0, config.devices[clip.device].kind === 'browser' ? first : refine(frames, first, timeline));
  const marks = timeline.marks.filter(({ name }) => name in nominal && name !== 'first').map(({ name, time }) => [nominal[name], Number(time.toFixed(3))]);
  const spec = config.devices[clip.device];
  const taps = spec.kind === 'browser' ? webTaps(timeline) : iosTaps(file, start, timeline, spec);
  manifest[id] = { file: basename(file), start: Number(start.toFixed(3)), marks, taps };
  console.log(`${id}: starts at ${start.toFixed(2)} s, ${taps.length} taps, drift ${marks.map(([a, b]) => (b - a).toFixed(2)).join(' ')}`);
}
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
