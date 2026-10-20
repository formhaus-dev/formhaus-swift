import { join } from 'node:path';
import { readJSON, root } from './paths.mjs';

const dir = join(root, 'node_modules/@formhaus/core/tokens');
const files = ['primitive.tokens.json', 'semantic.tokens.json', 'modes/theme-light.tokens.json'];

const merge = (target, source) => {
  for (const [key, value] of Object.entries(source)) {
    target[key] = value && typeof value === 'object' && !('$value' in value) ? merge(target[key] ?? {}, value) : value;
  }
  return target;
};

const tree = files.reduce((all, file) => merge(all, readJSON(join(dir, file))), {});

const lookup = (path) => {
  const node = path.split('.').reduce((current, key) => current?.[key], tree);
  const token = node && '$value' in node ? node : node?.default;
  if (!token) throw new Error(`Unknown token ${path}`);
  return token.$value;
};

export const resolveColor = (value) => {
  const alias = typeof value === 'string' && value.match(/^\{(.+)\}$/);
  if (!alias) return typeof value === 'string' ? value : value.hex;
  return resolveColor(lookup(alias[1]));
};
