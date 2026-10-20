import { device } from './devices.js';
import { clamp, easeInOut, el, mix, motion, place } from './kit.js';

const move = 0.8;

const offset = (focus, item, zoom, height) => {
  const size = item.node.height * item.scale * zoom;
  if (focus === 'top') return 0;
  if (focus === 'bottom') return height - size;
  return height / 2 - focus * size;
};

export const twoUp = (layer, data, beat, region = { top: 130, height: 950 }, gap = 90) => {
  const box = el('div', 'abs camera', layer);
  Object.assign(box.style, { top: `${region.top}px`, width: '1920px', height: `${region.height}px` });
  const sides = Object.fromEntries(
    Object.entries(beat.devices).map(([side, name]) => {
      const node = device(box, data.devices[name]);
      return [side, { node, scale: region.height / node.height }];
    }),
  );
  const width = Object.values(sides).reduce((sum, item) => sum + item.node.width * item.scale, 0) + gap;
  let x = (1920 - width) / 2;
  for (const item of Object.values(sides)) {
    item.x = x;
    x += item.node.width * item.scale + gap;
  }
  const keys = beat.camera ?? [{ at: 0, zoom: 1, focus: Object.fromEntries(Object.keys(sides).map((side) => [side, 'top'])) }];
  const pose = (key, side) => ({ zoom: key.zoom, y: offset(key.focus[side], sides[side], key.zoom, region.height) });
  return {
    sides,
    frame(t) {
      const next = keys.findIndex((key) => key.at > t);
      const [a, b] = next === -1 ? [keys.at(-1), keys.at(-1)] : next === 0 ? [keys[0], keys[0]] : [keys[next - 1], keys[next]];
      const p = easeInOut(clamp((t - (b.at - move)) / move)) * motion.scale;
      for (const [side, item] of Object.entries(sides)) {
        const [from, to] = [pose(a, side), pose(b, side)];
        const zoom = mix(from.zoom, to.zoom, p);
        place(item.node.root, { x: 960 + (item.x - 960) * zoom, y: mix(from.y, to.y, p), scale: item.scale * zoom });
      }
    },
  };
};
