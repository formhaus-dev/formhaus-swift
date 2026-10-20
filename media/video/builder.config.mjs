import { join, resolve } from 'node:path';
import { defineConfig } from 'vite';

const editor = join(resolve(process.env.FORMHAUS_REPO ?? '../../../formhaus'), 'packages/editor-react');

export default defineConfig({
  logLevel: 'warn',
  resolve: { alias: { '@formhaus/editor-react': join(editor, 'dist') } },
  server: { host: '127.0.0.1', port: 0, fs: { allow: ['.', editor] } },
});
