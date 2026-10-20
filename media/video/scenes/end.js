import { swift } from './code.js';
import { captionHeight, el, place, progress, stack } from './kit.js';
import { deviceRow, showRow } from './row.js';

const rowHeight = 540;
const gap = 56;

export default async (layer, beat, data) => {
  const title = el('div', 'caption abs', layer, beat.title);
  const devices = deviceRow(layer, data, beat, rowHeight, gap);
  const tallest = Math.max(...devices.map((item) => item.node.height * item.scale));
  const install = el('div', 'card abs end-install', layer);
  install.innerHTML = swift(beat.install);
  const links = el('div', 'end-links abs', layer);
  const mark = el('img', null, links);
  mark.src = 'build/mark.svg';
  mark.alt = '';
  beat.links.forEach((text, index) => el('span', index === 0 ? 'end-link--main' : null, links, text));
  let rows;

  return {
    update(t) {
      rows ??= stack([[captionHeight, gap], [tallest, gap], [install.offsetHeight, gap * 0.75], [links.offsetHeight]], 8);
      const [captionY, devicesY, installY, linksY] = rows;
      place(title, { y: captionY + (1 - progress(t, 0, 0.7)) * 16, opacity: progress(t, 0, 0.7) });
      devices.forEach((item, index) => {
        const p = progress(t, 0.25 + index * 0.12, 0.8);
        const y = devicesY + (tallest - item.node.height * item.scale) / 2;
        place(item.node.root, { x: item.x, y: y + (1 - p) * 30, scale: item.scale, opacity: p });
      });
      place(install, { x: (1920 - install.offsetWidth) / 2, y: installY + (1 - progress(t, 0.8, 0.5)) * 14, opacity: progress(t, 0.8, 0.5) });
      place(links, { y: linksY, opacity: progress(t, 1.1, 0.5) });
      return showRow(devices);
    },
  };
};
