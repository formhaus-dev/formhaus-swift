import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { definitions } from './definitions.mjs';
import { footage, root } from './paths.mjs';

const server = spawn(join(root, 'node_modules/.bin/formhaus-mcp'), [], { stdio: ['pipe', 'pipe', 'inherit'] });
const pending = new Map();
let buffer = '';
server.stdout.on('data', (chunk) => {
  buffer += chunk;
  for (let end = buffer.indexOf('\n'); end >= 0; end = buffer.indexOf('\n')) {
    const message = JSON.parse(buffer.slice(0, end));
    buffer = buffer.slice(end + 1);
    pending.get(message.id)?.(message);
  }
});

let id = 0;
const request = (method, params) =>
  new Promise((done) => {
    id += 1;
    pending.set(id, done);
    server.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`);
  });

const timer = setTimeout(() => {
  server.kill();
  throw new Error('The formhaus MCP server did not answer');
}, 30000);
await request('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'video', version: '1' } });
server.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' })}\n`);
const { result } = await request('tools/call', { name: 'validate_definition', arguments: { definition: definitions().base } });
clearTimeout(timer);
server.kill();
const output = result.content.map((item) => item.text).join('\n');
writeFileSync(join(footage, 'mcp.json'), JSON.stringify({ tool: 'validate_definition', output, issues: JSON.parse(output).issues.length }, null, 2));
console.log(`validate_definition: ${output}`);
