import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import { fixtures, readJSON } from './paths.mjs';

const jsonFiles = (dir) =>
  readdirSync(dir)
    .filter((name) => name.endsWith('.json') && !name.includes('schema'))
    .sort();

export const conformance = () => {
  const words = (text) => text.replace(/-/g, ' ');
  const corpus = jsonFiles(fixtures).map((name) => `definition · ${words(readJSON(join(fixtures, name)).name)}`);
  const dir = join(fixtures, 'scenarios');
  const engine = jsonFiles(dir).flatMap((name) => {
    const file = name.replace(/\.json$/, '');
    return (readJSON(join(dir, name)).scenarios ?? []).map((scenario) => `${words(file)} · ${scenario.name.replace(/ - /g, ', ')}`);
  });
  const names = [...engine, ...corpus];
  return { count: names.length, names };
};
