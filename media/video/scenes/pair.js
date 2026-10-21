import { device } from './devices.js';
import { captionHeight, el, mix, place, stack } from './kit.js';

const safeWidth = 1920 - 2 * 150;

export const pair = (layer, data, beat, { gap = 48, head = captionHeight, height = 736, to } = {}) => {
  const box = el('div', 'abs', layer);
  const nodes = Object.fromEntries(Object.entries(beat.devices).map(([side, name]) => [side, device(box, data.devices[name])]));
  const layout = (headHeight, deviceHeight) => {
    const scales = Object.values(nodes).map((node) => deviceHeight / node.height);
    const natural = Object.values(nodes).reduce((sum, node, index) => sum + node.width * scales[index], 0);
    const fit = Math.min(1, (safeWidth - gap) / natural);
    const scaled = scales.map((scale) => scale * fit);
    const tallest = Math.max(...Object.values(nodes).map((node, index) => node.height * scaled[index]));
    const [captionY, devicesY] = stack([[headHeight, 48], [tallest]]);
    let x = (1920 - natural * fit - gap) / 2;
    const items = Object.values(nodes).map((node, index) => {
      const item = { x, scale: scaled[index], y: devicesY + (tallest - node.height * scaled[index]) / 2 };
      x += node.width * scaled[index] + gap;
      return item;
    });
    return { items, captionY, middle: devicesY + tallest / 2 };
  };
  const from = layout(head, height);
  const target = to ? layout(to.head ?? captionHeight, to.height ?? 736) : from;
  const sides = Object.fromEntries(Object.entries(nodes).map(([side, node], index) => [side, { node, ...from.items[index] }]));
  return {
    sides,
    captionY: from.captionY,
    targetCaptionY: target.captionY,
    middle: from.middle,
    frame(motion = () => ({}), blend = 0) {
      Object.values(nodes).forEach((node, index) => {
        const { rise = 0, grow = 1, opacity = 1 } = motion(index);
        const a = from.items[index];
        const b = target.items[index];
        const scale = mix(a.scale, b.scale, blend);
        const width = node.width * scale;
        const height = node.height * scale;
        const x = mix(a.x, b.x, blend) + (width * (1 - grow)) / 2;
        const y = mix(a.y, b.y, blend) + (height * (1 - grow)) / 2 + rise;
        place(node.root, { x, y, scale: scale * grow, opacity });
      });
    },
  };
};
