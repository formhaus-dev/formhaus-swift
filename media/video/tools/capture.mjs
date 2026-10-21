import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { build } from './build.mjs';
import { withComposition } from './page.mjs';
import { root } from './paths.mjs';

const scale = Number(process.argv[2] ?? 1);
const gif = process.argv[3] === 'gif';
const data = build();
const { height } = data.output;
const fps = gif ? data.output.gif.fps : data.output.fps;
const step = data.output.fps / fps;
const out = join(root, 'out');
mkdirSync(out, { recursive: true });
const target = join(out, gif ? 'master-gif.mkv' : `master-${height * scale}.mkv`);

const encoder = spawn(
  'ffmpeg',
  ['-v', 'error', '-y', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-', '-c:v', 'libx264', '-preset', 'ultrafast', '-qp', '0', '-pix_fmt', 'yuv444p', target],
  { stdio: ['pipe', 'inherit', 'inherit'] },
);
const finished = new Promise((done, fail) => encoder.on('close', (code) => (code === 0 ? done() : fail(new Error(`ffmpeg exited with ${code}`)))));
const write = (buffer) => new Promise((done) => (encoder.stdin.write(buffer) ? done() : encoder.stdin.once('drain', done)));

try {
  await withComposition(data, scale, gif ? 'capture&calm' : 'capture', async (page) => {
    const begin = Date.now();
    for (let frame = 0; frame < Math.min(data.frames, Number(process.env.FRAMES ?? data.frames)); frame += step) {
      await page.evaluate((n) => window.renderFrame(n), Math.round(frame));
      await write(await page.screenshot({ type: 'png' }));
      if (Math.round(frame) % 300 === 0) console.log(`${height * scale}p frame ${frame}/${data.frames} ${((Date.now() - begin) / 1000).toFixed(0)} s`);
    }
  });
} finally {
  encoder.stdin.end();
}
await finished;
console.log(target);
