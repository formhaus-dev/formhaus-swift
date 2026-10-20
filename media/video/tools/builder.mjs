import { existsSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { createServer } from 'vite';
import { root } from './paths.mjs';

export const formhausRepo = resolve(process.env.FORMHAUS_REPO ?? join(root, '../../../formhaus'));

export const startBuilder = async () => {
  if (!existsSync(join(formhausRepo, 'packages/editor-react/dist/mount.js'))) {
    throw new Error(`No built editor in ${formhausRepo}. Set FORMHAUS_REPO to a formhaus checkout with packages built.`);
  }
  const server = await createServer({ configFile: join(root, 'builder.config.mjs'), root });
  await server.listen();
  const origin = server.resolvedUrls.local[0].replace(/\/$/, '');
  return { origin, close: () => server.close() };
};
