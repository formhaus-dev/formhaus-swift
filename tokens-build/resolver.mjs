import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export function readResolver(tokensDir) {
  const resolver = JSON.parse(readFileSync(resolve(tokensDir, 'formhaus.resolver.json'), 'utf8'));
  const files = (list) => list.map(({ $ref }) => resolve(tokensDir, $ref));
  const steps = resolver.resolutionOrder.map(({ $ref }) => {
    const [, kind, name] = /^#\/(sets|modifiers)\/([^/]+)$/.exec($ref);
    return { kind, name, target: resolver[kind][name] };
  });
  return (selected) => {
    for (const name of Object.keys(selected)) {
      if (!resolver.modifiers[name]?.contexts[selected[name]]) throw new Error(`no context ${name}.${selected[name]}`);
    }
    return steps.flatMap(({ kind, name, target }) =>
      kind === 'sets' ? files(target.sources) : files(target.contexts[selected[name] ?? target.default]),
    );
  };
}
