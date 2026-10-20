import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import StyleDictionary from 'style-dictionary';
import { ALIASES, CONTEXTS, CONTROLS, PALETTE, RADII, SHADOW, SPACING, STEPS, TYPOGRAPHY } from './mapping.mjs';
import { readResolver } from './resolver.mjs';
import { swiftSource } from './swift.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const tokensDir = resolve(root, 'Tests/FormhausUITests/Fixtures/tokens');
const target = 'Sources/FormhausUI/Theme/FormhausTokens.generated.swift';
const sourcesFor = readResolver(tokensDir);

const hooks = {
  transforms: {
    'fh/name': { type: 'name', transform: (token) => token.path.filter((part) => part !== 'default').join('-') },
  },
  formats: {
    'formhaus/swift': ({ options }) => swiftSource(options.contexts),
  },
};

const config = (source, files = []) => ({
  source,
  usesDtcg: true,
  log: { verbosity: 'silent', warnings: 'disabled' },
  hooks,
  platforms: { swift: { transforms: ['fh/name'], files } },
});

async function resolveContext(selected) {
  const { allTokens } = await new StyleDictionary(config(sourcesFor(selected))).getPlatformTokens('swift');
  const tokens = new Map(allTokens.filter((token) => !token.filePath.endsWith('primitive.tokens.json')).map((token) => [token.name, token]));
  return Object.assign(tokens, { paths: new Map(allTokens.map((token) => [token.path.join('.'), token])) });
}

const contexts = {};
for (const [name, selected] of Object.entries(CONTEXTS)) contexts[name] = await resolveContext(selected);

const mapped = new Set(
  [PALETTE, TYPOGRAPHY, STEPS, SPACING, RADII, CONTROLS].flatMap((fields) => fields.map(([, name]) => name)).concat(SHADOW),
);
const sameValue = (left, right) => JSON.stringify(left.$value) === JSON.stringify(right.$value);
for (const [contextName, tokens] of Object.entries(contexts)) {
  for (const name of tokens.keys()) {
    const alias = ALIASES.find(([aliasName]) => aliasName === name);
    if (!alias && !mapped.has(name)) throw new Error(`${name} has no Swift mapping`);
    if (!alias || (alias[2] && !alias[2].includes(contextName))) continue;
    if (!sameValue(tokens.get(name), tokens.get(alias[1]))) throw new Error(`${name} differs from ${alias[1]} in ${contextName}`);
  }
}

const dictionary = new StyleDictionary(
  config(sourcesFor({}), [{ destination: target, format: 'formhaus/swift', options: { contexts } }]),
);
const [{ output }] = await dictionary.formatPlatform('swift');
const formatted = execFileSync('swift', ['format', '--assume-filename', resolve(root, target), '-'], { input: output, encoding: 'utf8' });
const path = resolve(root, target);

if (process.argv.includes('--check')) {
  if (readFileSync(path, 'utf8') !== formatted) {
    console.error(`${target} is out of date. Run npm --prefix tokens-build run build.`);
    process.exit(1);
  }
} else {
  writeFileSync(path, formatted);
}
