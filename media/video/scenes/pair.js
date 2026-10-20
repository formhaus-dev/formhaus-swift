import { device } from './devices.js';
import { el, mix, motion, place, progress } from './kit.js';

export const pair = (layer, data, beat, { gap = 48, top = 214, height = 818 } = {}) => {
  const box = el('div', 'abs', layer);
  const sides = Object.fromEntries(
    Object.entries(beat.devices).map(([side, name]) => {
      const node = device(box, data.devices[name]);
      return [side, { node, scale: height / node.height }];
    }),
  );
  const width = Object.values(sides).reduce((sum, item) => sum + item.node.width * item.scale, 0) + gap;
  let x = (1920 - width) / 2;
  for (const item of Object.values(sides)) {
    item.x = x;
    x += item.node.width * item.scale + gap;
  }
  return {
    sides,
    frame(t) {
      const push = mix(beat.push ?? 0.97, 1, motion.scale * progress(t, 0, beat.duration, (p) => p)) || 1;
      for (const item of Object.values(sides)) {
        const scale = item.scale * push;
        const itemHeight = item.node.height * scale;
        place(item.node.root, { x: 960 + (item.x - 960) * push, y: top + (height - itemHeight) / 2, scale });
      }
    },
  };
};
