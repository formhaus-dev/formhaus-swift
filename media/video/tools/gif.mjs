import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync, rmSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { root, script } from './paths.mjs';

const { gif, name } = script().output;
const out = join(root, 'out');
const source = join(out, 'master-gif.mkv');
const dir = join(out, 'gif-frames');
const target = join(out, `${name}.gif`);

const run = (command, args) => {
  const result = spawnSync(command, args, { stdio: ['ignore', 'ignore', 'inherit'] });
  if (result.status !== 0) throw new Error(`${command} failed`);
};

rmSync(dir, { recursive: true, force: true });
mkdirSync(dir, { recursive: true });
run('ffmpeg', ['-v', 'error', '-i', source, '-vf', `scale=${gif.width}:-2:flags=lanczos`, join(dir, '%05d.png')]);
const frames = readdirSync(dir).map((file) => join(dir, file)).sort();
for (const quality of [100, 95, 90, 85, 80, 75, 70]) {
  run('gifski', ['--quiet', '--fps', String(gif.fps), '--width', String(gif.width), '--quality', String(quality), '-o', target, ...frames]);
  const size = statSync(target).size;
  console.log(`gif quality ${quality}: ${(size / 1e6).toFixed(2)} MB`);
  if (size <= gif.maxBytes) break;
}
rmSync(dir, { recursive: true, force: true });
