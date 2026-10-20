import { spawnSync } from 'node:child_process';

const grab = (file, time, [width, height], format) => {
  const filter = `scale=${width}:${height},fps=30,trim=start=${time.toFixed(3)},setpts=PTS-STARTPTS,format=${format}`;
  const { stdout } = spawnSync('ffmpeg', ['-v', 'error', '-fflags', '+igndts', '-i', file, '-vf', filter, '-frames:v', '1', '-f', 'rawvideo', '-'], {
    maxBuffer: 64 * 1024 * 1024,
  });
  return stdout;
};

const cell = 4;

const components = (active, columns, rows) => {
  const seen = new Uint8Array(active.length);
  const found = [];
  for (let start = 0; start < active.length; start += 1) {
    if (!active[start] || seen[start]) continue;
    const box = { minX: Infinity, minY: Infinity, maxX: -1, maxY: -1, count: 0 };
    const stack = [start];
    seen[start] = 1;
    while (stack.length) {
      const index = stack.pop();
      const x = index % columns;
      const y = Math.floor(index / columns);
      Object.assign(box, { minX: Math.min(box.minX, x), minY: Math.min(box.minY, y), maxX: Math.max(box.maxX, x), maxY: Math.max(box.maxY, y) });
      box.count += 1;
      for (const next of [index - 1, index + 1, index - columns, index + columns]) {
        const nx = next % columns;
        if (next < 0 || next >= active.length || seen[next] || !active[next] || Math.abs(nx - x) > 1) continue;
        seen[next] = 1;
        stack.push(next);
      }
    }
    found.push({ x: (box.minX + box.maxX + 1) * cell * 0.5, y: (box.minY + box.maxY + 1) * cell * 0.5, height: (box.maxY - box.minY + 1) * cell, ...box });
  }
  return found.sort((a, b) => b.count - a.count);
};

const cells = (region, test) => {
  const columns = Math.ceil(region.width / cell);
  const rows = Math.ceil(region.height / cell);
  const active = new Uint8Array(columns * rows);
  for (let y = 0; y < region.height; y += 1) {
    for (let x = 0; x < region.width; x += 1) {
      if (test(region.x + x, region.y + y)) active[Math.floor(y / cell) * columns + Math.floor(x / cell)] = 1;
    }
  }
  return components(active, columns, rows).map((item) => ({ ...item, x: item.x + region.x, y: item.y + region.y }));
};

const clip = (size, frame) => {
  const [x, y, w, h] = frame ?? [0, 0, ...size];
  const left = Math.max(0, Math.floor(x));
  const top = Math.max(0, Math.floor(y));
  return { x: left, y: top, width: Math.min(size[0], Math.ceil(x + w)) - left, height: Math.min(size[1], Math.ceil(y + h)) - top };
};

const changed = (file, start, tap, size) => {
  const [width, height] = size;
  const before = grab(file, start + tap.time - 0.06, size, 'gray');
  const later = grab(file, start + tap.time + 0.4, size, 'gray');
  const [dx, dy] = tap.frame && tap.after ? [tap.after[0] - tap.frame[0], tap.after[1] - tap.frame[1]].map(Math.round) : [0, 0];
  const differs = (x, y) => {
    const [bx, by] = [x - dx, y - dy];
    if (bx < 0 || by < 0 || bx >= width || by >= height) return false;
    return Math.abs(later[y * width + x] - before[by * width + bx]) > 18;
  };
  const found = cells(clip(size, tap.after ?? tap.frame), differs);
  if (!found.length) return null;
  const spot = tap.type === 'rating' ? found.sort((a, b) => b.maxX - a.maxX)[0] : found[0];
  return { x: spot.x - dx, y: spot.y - dy };
};

const button = (file, start, tap, size, [r, g, b]) => {
  const pixels = grab(file, start + tap.time - 0.06, size, 'rgb24');
  const near = (x, y) => {
    const index = (y * size[0] + x) * 3;
    return Math.abs(pixels[index] - r) + Math.abs(pixels[index + 1] - g) + Math.abs(pixels[index + 2] - b) < 60;
  };
  return cells(clip(size, null), near).find((item) => item.height >= 30) ?? null;
};

export const locateTaps = (file, start, timeline, size, primary) =>
  timeline.taps
    .map((tap) => {
      if (tap.kind === 'back') return null;
      const spot = ['next', 'submit'].includes(tap.kind) ? button(file, start, tap, size, primary) : changed(file, start, tap, size);
      return spot && { time: tap.time, kind: tap.kind, x: spot.x / size[0], y: spot.y / size[1] };
    })
    .filter(Boolean);
