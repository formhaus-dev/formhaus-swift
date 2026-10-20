import { swift } from './code.js';
import { device } from './devices.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';

const rowHeight = 560;
const gap = 72;

export default async (layer, beat, data) => {
  const title = el('h1', 'headline headline--center abs', layer, beat.title);
  title.style.fontSize = '60px';
  const devices = beat.devices.map((name) => {
    const node = device(layer, data.devices[name]);
    const time = beat.at[name] ? data.marks.tour[beat.at[name]] + 0.4 : 0;
    return { node, scale: rowHeight / node.height, clip: footage(data, beat.stills[name], node.img), time };
  });
  const width = devices.reduce((sum, item) => sum + item.node.width * item.scale, 0) + gap * (devices.length - 1);
  let x = (1920 - width) / 2;
  for (const item of devices) {
    item.x = x;
    x += item.node.width * item.scale + gap;
  }

  const install = el('div', 'card abs end-install', layer);
  install.innerHTML = swift(beat.install);
  const links = el('div', 'end-links abs', layer);
  const mark = el('img', null, links);
  mark.src = 'build/mark.svg';
  mark.alt = '';
  beat.links.forEach((text, index) => el('span', index === 0 ? 'end-link--main' : null, links, text));

  return {
    update(t) {
      place(title, { y: 92 + (1 - progress(t, 0, 0.7)) * 16, opacity: progress(t, 0, 0.7) });
      devices.forEach((item, index) => {
        const p = progress(t, 0.25 + index * 0.12, 0.8);
        place(item.node.root, { x: item.x, y: 196 + (1 - p) * 30 + (rowHeight - item.node.height * item.scale), scale: item.scale, opacity: p });
      });
      place(install, { x: (1920 - install.offsetWidth) / 2, y: 806 + (1 - progress(t, 1.2, 0.6)) * 14, opacity: progress(t, 1.2, 0.6) });
      place(links, { y: 944, opacity: progress(t, 1.7, 0.6) });
      return Promise.all(devices.map((item) => item.clip.at(item.time)));
    },
  };
};
