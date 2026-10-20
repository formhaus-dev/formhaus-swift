import { device } from './devices.js';
import { footage } from './footage.js';

export const deviceRow = (layer, data, beat, height, gap) => {
  const items = beat.devices.map((name) => {
    const node = device(layer, data.devices[name]);
    const at = typeof beat.at === 'number' ? beat.at : beat.at?.[name];
    const time = typeof at === 'string' ? data.marks.tour[at] + 0.4 : (at ?? 0);
    return { name, node, scale: height / node.height, clip: footage(data, beat.stills[name], node.img), time };
  });
  const natural = items.reduce((sum, item) => sum + item.node.width * item.scale, 0);
  const fit = Math.min(1, (1920 - 300 - gap * (items.length - 1)) / natural);
  for (const item of items) item.scale *= fit;
  const width = natural * fit + gap * (items.length - 1);
  let x = (1920 - width) / 2;
  for (const item of items) {
    item.x = x;
    item.width = item.node.width * item.scale;
    x += item.width + gap;
  }
  return items;
};

export const showRow = (items) => Promise.all(items.map((item) => item.clip.at(item.time)));
