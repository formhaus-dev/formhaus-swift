import { join } from 'node:path';
import { build } from './build.mjs';
import { withComposition } from './page.mjs';
import { root } from './paths.mjs';

const data = build();
const { fps, poster } = data.output;
const beat = data.beats.find((item) => item.id === poster.beat);
const frame = Math.round((beat.start + poster.at) * fps);
await withComposition(data, 1, `frame=${frame}`, (page) => page.screenshot({ path: join(root, 'out', 'poster.png') }));
