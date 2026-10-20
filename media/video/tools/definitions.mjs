import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { definitionSource, footage, readJSON, script } from './paths.mjs';

const setPath = (target, path, value) => {
  const keys = path.split('.');
  const last = keys.pop();
  const parent = keys.reduce((node, key) => node[key], target);
  parent[last] = value;
};

export const definitions = () => {
  const { edit } = script();
  const base = readJSON(definitionSource);
  const variant = structuredClone(base);
  const step = (definition) => definition.steps.find((item) => item.id === edit.step);
  setPath(step(variant), edit.property, edit.value);
  return { base, variant };
};

if (process.argv[1] && process.argv[1].endsWith('definitions.mjs')) {
  const dir = join(footage, 'definitions');
  mkdirSync(dir, { recursive: true });
  const { base, variant } = definitions();
  writeFileSync(join(dir, 'base.json'), JSON.stringify(base));
  writeFileSync(join(dir, 'variant.json'), JSON.stringify(variant, null, 2));
}
