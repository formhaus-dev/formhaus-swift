import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { definitionSource, footage, readJSON } from './paths.mjs';

export const definitions = () => ({ base: readJSON(definitionSource) });

if (process.argv[1] && process.argv[1].endsWith('definitions.mjs')) {
  const dir = join(footage, 'definitions');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'base.json'), JSON.stringify(definitions().base));
}
