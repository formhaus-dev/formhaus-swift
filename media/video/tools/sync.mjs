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

const transitions = ['next', 'submit'];

const vote = (frames, timeline) => {
  const changes = frames.filter((frame) => frame.score > 0.02).map((frame) => frame.time);
  const small = frames.filter((frame) => frame.score > 0.003).map((frame) => frame.time);
  const taps = timeline.taps.filter((tap) => transitions.includes(tap.kind));
  const gap = (list, start, tap) => {
    const delta = list.map((time) => time - start - tap.time).find((value) => value > -0.05 && value < 0.35);
    return delta === undefined ? null : Math.abs(delta);
  };
  const hits = (start) =>
    timeline.taps.reduce((sum, tap) => {
      const major = transitions.includes(tap.kind);
      const delta = gap(major ? changes : small, start, tap);
      return delta === null ? sum : sum + (major ? 20 : 10) - delta;
    }, 0);
  const candidates = changes.flatMap((time) => taps.map((tap) => time - tap.time)).filter((start) => start >= 0);
  const best = candidates.reduce((top, start) => (hits(start) > hits(top) ? start : top), candidates[0]);
  if (best === undefined) throw new Error('No step change found to sync on');
  const offsets = taps
    .map((tap) => changes.find((time) => time - best - tap.time > -0.05 && time - best - tap.time < 0.35))
    .map((time, index) => time && time - taps[index].time)
    .filter((value) => value !== undefined)
    .sort((x, y) => x - y);
  return offsets[0] ?? best;
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
  const browser = config.devices[clip.device].kind === 'browser';
  const start = browser ? timeline.offset : vote(frames, timeline);
  const marks = timeline.marks.filter(({ name }) => name in nominal && name !== 'first').map(({ name, time }) => [nominal[name], Number(time.toFixed(3))]);
  const spec = config.devices[clip.device];
  const taps = spec.kind === 'browser' ? webTaps(timeline) : iosTaps(file, start, timeline, spec);
  manifest[id] = { file: basename(file), start: Number(start.toFixed(3)), marks, taps };
  console.log(`${id}: starts at ${start.toFixed(2)} s, ${taps.length} taps, drift ${marks.map(([a, b]) => (b - a).toFixed(2)).join(' ')}`);
}
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
