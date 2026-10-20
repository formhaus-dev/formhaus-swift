import { createReadStream, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize } from 'node:path';
import { root } from './paths.mjs';

const types = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.jpg': 'image/jpeg',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
};

const resolve = (url) => {
  const path = normalize(decodeURIComponent(new URL(url, 'http://x').pathname)).replace(/^(\.\.[/\\])+/, '');
  const file = join(root, path);
  return statSync(file, { throwIfNoEntry: false })?.isDirectory() ? join(file, 'index.html') : file;
};

export const serve = () =>
  new Promise((done) => {
    const server = createServer((request, response) => {
      const file = resolve(request.url);
      if (!file.startsWith(root) || !statSync(file, { throwIfNoEntry: false })?.isFile()) {
        response.writeHead(404).end();
        return;
      }
      response.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
      createReadStream(file).pipe(response);
    });
    server.listen(0, '127.0.0.1', () => {
      const origin = `http://127.0.0.1:${server.address().port}`;
      done({ origin, close: () => new Promise((closed) => server.close(closed)) });
    });
  });

if (process.argv[1]?.endsWith('serve.mjs')) {
  const { origin } = await serve();
  console.log(`${origin}/index.html`);
}
