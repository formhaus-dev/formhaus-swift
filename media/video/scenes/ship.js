import { jsonCard } from './jsoncard.js';
import { easeInOut, el, mix, place, progress } from './kit.js';
import { deviceRow, showRow } from './row.js';

const rowHeight = 600;
const top = 150;

export default async (layer, beat, data) => {
  const devices = deviceRow(layer, data, beat, rowHeight, 80);
  const copies = devices.map(() => jsonCard(layer, data, 15));
  for (const { card } of copies) card.style.width = '780px';
  const caption = el('div', 'caption abs', layer, beat.caption);

  return {
    update(t) {
      const fly = progress(t, 0.2, 0.8, easeInOut);
      devices.forEach((item, index) => {
        const y = top + rowHeight - item.node.height * item.scale;
        const shown = progress(t, 0.7 + index * 0.06, 0.4);
        place(item.node.root, { x: item.x, y: y + (1 - shown) * 18, scale: item.scale, opacity: shown });
        const { card } = copies[index];
        const width = 780;
        const height = card.offsetHeight || 640;
        const scale = mix(0.62, item.width / width, fly);
        const centerX = mix(960, item.x + item.width / 2, fly);
        const centerY = mix(500, y + (item.node.height * item.scale) / 2, fly);
        place(card, { x: centerX - (width * scale) / 2, y: centerY - (height * scale) / 2, scale, opacity: (index === 1 ? 1 : fly) * (1 - progress(t, 0.75, 0.3)) });
      });
      place(caption, { y: 860 + (1 - progress(t, 1.3, 0.6)) * 14, opacity: progress(t, 1.3, 0.6) });
      return showRow(devices);
    },
  };
};
