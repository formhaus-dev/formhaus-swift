import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { build } from './build.mjs';
import { withComposition } from './page.mjs';
import { root } from './paths.mjs';

const data = build();
const dir = join(root, 'out', 'stills');
mkdirSync(dir, { recursive: true });
await withComposition(data, Number(process.env.SCALE ?? 1), 'capture', async (page) => {
  for (const second of process.argv.slice(2).map(Number)) {
    await page.evaluate((n) => window.renderFrame(n), Math.round(second * data.output.fps));
    const path = join(dir, `${String(second).replace('.', '_')}.png`);
    await page.screenshot({ path });
    console.log(path);
  }
});
