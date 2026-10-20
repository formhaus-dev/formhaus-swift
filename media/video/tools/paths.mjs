import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = join(dirname(fileURLToPath(import.meta.url)), '..');
export const repo = join(root, '..', '..');
export const footage = join(root, 'footage');
export const frames = join(footage, 'frames');
export const definitionSource = join(repo, 'Examples/FormhausDemo/FormhausDemo/Resources/project-inquiry.json');
export const fixtures = join(repo, 'Tests/FormhausCoreTests/Fixtures/conformance');

export const readJSON = (path) => JSON.parse(readFileSync(path, 'utf8'));
export const script = () => readJSON(join(root, 'script.json'));
