import { swift } from './code.js';
import { device } from './devices.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';

export default async (layer, beat, data) => {
  const spec = data.devices[beat.device];
  const phone = device(layer, spec);
  const clip = footage(data, beat.clip, phone.img);
  const marks = data.marks.styles;
  const start = marks[beat.play.from] - beat.play.lead;
  const until = marks[beat.play.until] - 0.05;
  const scale = 940 / phone.height;

  const title = el('h1', 'headline abs', layer, beat.title);
  title.style.fontSize = '56px';
  const card = el('div', 'card abs', layer);
  card.style.width = '720px';
  const pre = el('pre', 'code', card);
  pre.style.fontSize = '24px';
  pre.style.padding = '30px 34px';
  const first = el('span', 'code__line', pre);
  first.innerHTML = swift(beat.code);
  const slot = el('span', 'code__line code-slot', pre);
  const lines = beat.sets.map((set) => {
    const node = el('span', 'code-swap', slot);
    node.innerHTML = swift(`    ${set.line}`);
    return { ...set, node, time: marks[set.at] - start };
  });
  const chips = el('div', 'chips abs', layer);
  const chipNodes = lines.map((set) => el('span', 'chip', chips, set.name));

  return {
    update(t) {
      place(phone.root, { x: 620 - (phone.width * scale) / 2, y: 70 + (1 - progress(t, 0, 0.8)) * 26, scale });
      place(title, { x: 1020, y: 330, opacity: progress(t, 0.15, 0.6) });
      place(card, { x: 1020, y: 450, opacity: progress(t, 0.35, 0.6) });
      place(chips, { x: 1020, y: 640, opacity: progress(t, 0.5, 0.6) });
      const active = Math.max(0, lines.findLastIndex((set) => t >= set.time));
      lines.forEach((set, index) => {
        const enter = index === 0 ? 1 : progress(t, set.time, 0.4);
        const leave = lines[index + 1] ? progress(t, lines[index + 1].time, 0.4) : 0;
        set.node.style.opacity = String(enter * (1 - leave));
        set.node.style.transform = `translateY(${(1 - enter) * 16 - leave * 16}px)`;
      });
      chipNodes.forEach((chip, index) => chip.classList.toggle('chip--on', index === active));
      return clip.at(Math.min(start + t, until));
    },
  };
};
