import { execFileSync } from 'node:child_process';
import { script } from './paths.mjs';

const config = script();

const udid = (name) => {
  const { devices } = JSON.parse(execFileSync('xcrun', ['simctl', 'list', 'devices', 'available', '-j'], { encoding: 'utf8' }));
  const runtimes = Object.keys(devices)
    .filter((runtime) => runtime.includes('iOS'))
    .sort((a, b) => b.localeCompare(a, 'en', { numeric: true }));
  for (const runtime of runtimes) {
    const device = devices[runtime].find((item) => item.name === name);
    if (device) return device.udid;
  }
  throw new Error(`No available simulator named ${name}`);
};

const mode = { '--web': ['browser'], '--mac': ['mac'] }[process.argv[2]];
const wanted = process.argv.slice(mode ? 3 : 2);
const kinds = mode ?? ['iphone', 'ipad'];
const clips = Object.entries(config.footage).filter(
  ([id, clip]) => kinds.includes(config.devices[clip.device].kind) && (wanted.length === 0 || wanted.includes(id)),
);
const lines = mode ? [clips.map(([id]) => id).join(' ')] : clips
  .sort(([, a], [, b]) => a.device.localeCompare(b.device))
  .map(([id, clip]) => {
    const marks = config.marks[clip.script];
    const settle = clip.stop ? marks[clip.stop] + 2 : 0;
    return [id, udid(config.devices[clip.device].simulator), clip.script, clip.stop ?? '-', clip.definition, clip.still ? 'still' : 'video', Math.ceil(clip.still ? settle : clip.length + 3)].join(' ');
  });
console.log(lines.join('\n'));
