import { device } from './devices.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';

const height = 860;
const gap = 100;

export default async (layer, beat, data) => {
  const title = el('div', 'caption abs', layer, beat.title);
  const phones = beat.sets.map((set) => {
    const node = device(layer, data.devices.iphone);
    const label = el('div', 'look-label abs', layer, set.name);
    return { node, label, clip: footage(data, beat.clip, node.img), time: data.marks.styles[set.at] + set.offset };
  });
  const scale = height / phones[0].node.height;
  const width = phones[0].node.width * scale;
  const left = (1920 - width * phones.length - gap * (phones.length - 1)) / 2;

  return {
    update(t) {
      place(title, { y: 24, opacity: progress(t, 0, 0.5) });
      phones.forEach((phone, index) => {
        const x = left + index * (width + gap);
        const shown = progress(t, 0.2 + index * 0.25, 0.6);
        place(phone.node.root, { x, y: 118 + (1 - shown) * 20, scale, opacity: shown });
        phone.label.style.width = `${width}px`;
        place(phone.label, { x, y: 1000, opacity: shown });
      });
      return Promise.all(phones.map((phone) => phone.clip.at(phone.time)));
    },
  };
};
