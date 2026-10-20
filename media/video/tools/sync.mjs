import { spawnSync } from 'node:child_process';
import { existsSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { footage, readJSON, script } from './paths.mjs';

const config = script();
const manifestPath = join(footage, 'manifest.json');
const manifest = existsSync(manifestPath) ? readJSON(manifestPath) : {};

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
  const event = launch && frames.find((frame) => frame.time > launch.time + 0.3 && frame.score > 0.02);
  if (!event) throw new Error('No first event found');
  return event.time;
};

const measureMarks = (frames, start, marks, stop) => {
  const measured = [];
  let drift = 0;
  for (const [mark, time] of Object.entries(marks)) {
    if (mark === stop) break;
    if (mark === 'first' || mark === 'end') continue;
    const expected = start + time + drift;
    const hit = frames.find((frame) => frame.time >= expected - 0.1 && frame.time <= expected + 0.8 && frame.score > 0.01);
    if (hit) drift = hit.time - start - time;
    measured.push([time, Number((time + drift).toFixed(3))]);
  }
  return measured;
};

for (const [id, clip] of Object.entries(config.footage)) {
  const file = source(id);
  if (!file) continue;
  if (clip.still) {
    manifest[id] = { file: basename(file), still: true };
    continue;
  }
  const frames = samples(file);
  const marks = config.marks[clip.script];
  const start = Math.max(0, firstEvent(frames) - marks.first);
  const measured = measureMarks(frames, start, marks, clip.stop);
  manifest[id] = { file: basename(file), start: Number(start.toFixed(3)), marks: measured };
  console.log(`${id}: starts at ${start.toFixed(2)} s, drift ${measured.map(([a, b]) => (b - a).toFixed(2)).join(' ')}`);
}
writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
