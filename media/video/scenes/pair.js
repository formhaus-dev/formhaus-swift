import { device } from './devices.js';
import { captionHeight, el, place, stack } from './kit.js';

const safeWidth = 1920 - 2 * 150;

export const pair = (layer, data, beat, { gap = 48, head = captionHeight, height = 736 } = {}) => {
  const box = el('div', 'abs', layer);
  const sides = Object.fromEntries(
    Object.entries(beat.devices).map(([side, name]) => {
      const node = device(box, data.devices[name]);
      return [side, { node, scale: height / node.height }];
    }),
  );
  const natural = Object.values(sides).reduce((sum, item) => sum + item.node.width * item.scale, 0);
  const fit = Math.min(1, (safeWidth - gap) / natural);
  for (const item of Object.values(sides)) item.scale *= fit;
  const width = natural * fit + gap;
  const tallest = Math.max(...Object.values(sides).map((item) => item.node.height * item.scale));
  const [captionY, devicesY] = stack([[head, 48], [tallest]]);
  let x = (1920 - width) / 2;
  for (const item of Object.values(sides)) {
    item.x = x;
    x += item.node.width * item.scale + gap;
  }
  return {
    sides,
    captionY,
    middle: devicesY + tallest / 2,
    frame(motion = () => ({})) {
      Object.values(sides).forEach((item, index) => {
        const { rise = 0, grow = 1, opacity = 1 } = motion(index);
        const width = item.node.width * item.scale;
        const height = item.node.height * item.scale;
        const x = item.x + (width * (1 - grow)) / 2;
        const y = devicesY + (tallest - height) / 2 + (height * (1 - grow)) / 2 + rise;
        place(item.node.root, { x, y, scale: item.scale * grow, opacity });
      });
    },
  };
};
