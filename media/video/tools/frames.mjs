import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { footage, frames, readJSON } from './paths.mjs';

const rate = 60;
const width = 804;
const manifest = readJSON(join(footage, 'manifest.json'));

const fresh = (source, info) => existsSync(info) && statSync(info).mtimeMs > statSync(source).mtimeMs;

const extract = (id, entry) => {
  const source = join(footage, entry.file);
  const dir = join(frames, id);
  const info = join(dir, 'info.json');
  if (entry.frames) return { ...readJSON(info), marks: entry.marks, taps: entry.taps, pointer: entry.pointer };
  if (fresh(source, info) && readJSON(info).start === entry.start) return { ...readJSON(info), marks: entry.marks ?? [], taps: entry.taps ?? [] };
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
  if (entry.still) {
    copyFileSync(source, join(dir, 'still.png'));
  } else {
    const filter = `trim=start=${entry.start},setpts=PTS-STARTPTS,scale=${width}:-2:flags=lanczos,format=yuvj444p`;
    const result = spawnSync('ffmpeg', ['-v', 'error', '-fflags', '+igndts', '-i', source, '-vf', filter, '-fps_mode', 'passthrough', '-q:v', '1', join(dir, '%05d.jpg')]);
    if (result.status !== 0) throw new Error(`ffmpeg failed for ${id}: ${result.stderr}`);
  }
  const count = entry.still ? 1 : readdirSync(dir).filter((name) => name.endsWith('.jpg')).length;
  const data = { start: entry.start, rate, count, still: Boolean(entry.still), ext: 'jpg' };
  writeFileSync(info, JSON.stringify(data));
  return { ...data, marks: entry.marks ?? [], taps: entry.taps ?? [] };
};

export const extractAll = () => Object.fromEntries(Object.entries(manifest).map(([id, entry]) => [id, extract(id, entry)]));

if (process.argv[1]?.endsWith('frames.mjs')) console.log(extractAll());
