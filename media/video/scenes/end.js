import { swift } from './code.js';
import { el, place, progress } from './kit.js';
import { deviceRow, showRow } from './row.js';

const rowHeight = 590;

export default async (layer, beat, data) => {
  const title = el('div', 'caption abs', layer, beat.title);
  const devices = deviceRow(layer, data, beat, rowHeight, 56);
  const install = el('div', 'card abs end-install', layer);
  install.innerHTML = swift(beat.install);
  const links = el('div', 'end-links abs', layer);
  const mark = el('img', null, links);
  mark.src = 'build/mark.svg';
  mark.alt = '';
  beat.links.forEach((text, index) => el('span', index === 0 ? 'end-link--main' : null, links, text));

  return {
    update(t) {
      place(title, { y: 96 + (1 - progress(t, 0, 0.7)) * 16, opacity: progress(t, 0, 0.7) });
      devices.forEach((item, index) => {
        const p = progress(t, 0.25 + index * 0.12, 0.8);
        place(item.node.root, { x: item.x, y: 214 + (1 - p) * 30 + (rowHeight - item.node.height * item.scale), scale: item.scale, opacity: p });
      });
      place(install, { x: (1920 - install.offsetWidth) / 2, y: 852 + (1 - progress(t, 1.2, 0.6)) * 14, opacity: progress(t, 1.2, 0.6) });
      place(links, { y: 980, opacity: progress(t, 1.7, 0.6) });
      return showRow(devices);
    },
  };
};
