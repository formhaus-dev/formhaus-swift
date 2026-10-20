import { defineConfig } from 'vite';

export default defineConfig({
  root: 'web',
  base: './',
  logLevel: 'warn',
  build: { outDir: 'dist', emptyOutDir: true, target: 'es2022' },
});
