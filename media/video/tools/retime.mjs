import { spawn, spawnSync } from 'node:child_process';
import { copyFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { footage } from './paths.mjs';

const cell = 12;
const cells = [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [0, 2]];
const blank = cell * 3;
const longest = 40;

const probe = (file) => {
  const { stdout } = spawnSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height:frame=pts_time', '-of', 'json', file], {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024,
  });
  const data = JSON.parse(stdout);
  return { width: data.streams[0].width, height: data.streams[0].height, times: data.frames.map((frame) => Number(frame.pts_time)) };
};

const decode = (file, filter, size, each) =>
  new Promise((done, fail) => {
    const decoder = spawn('ffmpeg', ['-v', 'error', '-i', file, '-fps_mode', 'passthrough', '-enc_time_base', 'demux', ...filter, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], { stdio: ['ignore', 'pipe', 'inherit'] });
    let frame = Buffer.alloc(size);
    let filled = 0;
    let index = 0;
    let chain = Promise.resolve();
    decoder.stdout.on('data', (chunk) => {
      let offset = 0;
      while (offset < chunk.length) {
        const count = Math.min(size - filled, chunk.length - offset);
        chunk.copy(frame, filled, offset, offset + count);
        filled += count;
        offset += count;
        if (filled < size) continue;
        const ready = frame;
        const current = index;
        index += 1;
        frame = Buffer.alloc(size);
        filled = 0;
        chain = chain.then(() => each(ready, current));
      }
      decoder.stdout.pause();
      chain.then(() => decoder.stdout.resume());
    });
    decoder.on('close', (code) => chain.then(() => (code === 0 ? done() : fail(new Error(`ffmpeg exited with ${code}`)))));
  });

const read = (frame, width) =>
  cells.reduce((value, [column, row], index) => {
    let sum = 0;
    for (let dy = -2; dy <= 2; dy += 1) {
      for (let dx = -2; dx <= 2; dx += 1) {
        const offset = ((row * cell + 6 + dy) * width + column * cell + 6 + dx) * 3;
        sum += frame[offset] + frame[offset + 1] + frame[offset + 2];
      }
    }
    return sum / 75 < 128 ? value | (1 << index) : value;
  }, 0);

const stepAt = (codes, index) => (codes[index] - codes[index - 1] + 64) % 64;

const ticking = (codes, index) => {
  const steps = Array.from({ length: 30 }, (_, offset) => stepAt(codes, index + offset + 1));
  return steps.every((step) => step <= 3) && steps.filter(Boolean).length >= 15;
};

const tickerRun = (codes) => {
  const first = codes.findIndex((_, index) => index + 31 < codes.length && ticking(codes, index));
  let last = first + 1;
  while (last < codes.length && stepAt(codes, last) <= longest) last += 1;
  return [first, last];
};

export const retime = async (id) => {
  const raw = join(footage, 'raw', `${id}.mov`);
  const target = join(footage, `${id}.mov`);
  const { width, height, times } = probe(raw);
  const codes = [];
  await decode(raw, ['-vf', `crop=${blank}:${blank}:0:0`], blank * blank * 3, (frame) => {
    codes.push(read(frame, blank));
  });
  const [first, last] = tickerRun(codes);
  const encoder = spawn(
    'ffmpeg',
    ['-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', `${width}x${height}`, '-framerate', '60', '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '6', '-pix_fmt', 'yuv444p', target],
    { stdio: ['pipe', 'inherit', 'inherit'] },
  );
  const finished = new Promise((done, fail) => encoder.on('close', (code) => (code === 0 ? done() : fail(new Error(`ffmpeg exited with ${code}`)))));
  const write = (buffer) => new Promise((done) => (encoder.stdin.write(buffer) ? done() : encoder.stdin.once('drain', done)));
  const gaps = [];
  let written = 0;
  let unwrapped = 0;
  await decode(raw, [], width * height * 3, async (frame, index) => {
    if (index < first || index >= last) return;
    if (index > first) unwrapped += stepAt(codes, index);
    const count = unwrapped + 1 - written;
    if (count <= 0) return;
    for (let y = 0; y < blank; y += 1) frame.fill(255, y * width * 3, (y * width + blank) * 3);
    if (count > 1) gaps.push({ at: Number((written / 60).toFixed(3)), missing: count - 1 });
    for (let repeat = 0; repeat < count; repeat += 1) await write(frame);
    written += count;
  });
  encoder.stdin.end();
  await finished;
  copyFileSync(join(footage, 'raw', `${id}.timeline.json`), join(footage, `${id}.timeline.json`));
  const deltas = times.slice(first + 1, last).map((time, index) => time - times[first + index]);
  const span = times[last - 1] - times[first];
  const report = {
    id,
    raw: { frames: times.length, ticked: last - first, seconds: Number(span.toFixed(3)), fps: Number(((last - first - 1) / span).toFixed(2)), maxDelta: Number(Math.max(...deltas).toFixed(4)) },
    output: { frames: written, fps: 60, seconds: Number((written / 60).toFixed(3)) },
    gaps,
    duplicates: codes.slice(first + 1, last).filter((code, index) => code === codes[first + index]).length,
    longestRawStep: Math.max(...Array.from({ length: last - first - 1 }, (_, index) => stepAt(codes, first + index + 1))),
  };
  writeFileSync(join(footage, 'raw', `${id}.retime.json`), `${JSON.stringify(report, null, 2)}\n`);
  return report;
};

if (process.argv[1]?.endsWith('retime.mjs')) {
  for (const id of process.argv.slice(2)) console.log(JSON.stringify(await retime(id)));
}
