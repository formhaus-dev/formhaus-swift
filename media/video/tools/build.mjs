import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { conformance } from './conformance.mjs';
import { definitions } from './definitions.mjs';
import { editLines } from './excerpt.mjs';
import { extractAll } from './frames.mjs';
import { repo, root, script } from './paths.mjs';
import { resolveColor } from './tokens.mjs';

export const build = () => {
  const config = script();
  const { base } = definitions();
  let start = 0;
  const beats = config.beats.map((beat) => {
    const placed = { ...beat, start };
    start += beat.duration;
    return placed;
  });
  const total = start;
  const colors = Object.fromEntries(Object.entries(config.theme.colors).map(([name, value]) => [name, resolveColor(value)]));
  const data = {
    ...config,
    beats,
    total,
    frames: Math.round(total * config.output.fps),
    theme: { ...config.theme, colors },
    footage: extractAll(),
    conformance: conformance(),
    edit: editLines(base, config.edit),
  };
  const dir = join(root, 'build');
  mkdirSync(dir, { recursive: true });
  copyFileSync(join(repo, 'Examples/FormhausDemo/FormhausDemo/Assets.xcassets/Mark.imageset/mark.svg'), join(dir, 'mark.svg'));
  writeFileSync(join(dir, 'data.json'), JSON.stringify(data));
  return data;
};

if (process.argv[1]?.endsWith('build.mjs')) {
  const data = build();
  console.log(`${data.beats.length} beats, ${data.total.toFixed(2)} s, ${data.frames} frames, ${data.conformance.count} conformance scenarios`);
}
