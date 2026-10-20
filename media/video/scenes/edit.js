import { json } from './code.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';
import { pair } from './parity.js';

const layers = (data, slot, ids) => {
  const after = slot.node.img.cloneNode();
  slot.node.screen.append(after);
  after.style.position = 'absolute';
  after.style.inset = '0';
  return { before: footage(data, ids.before, slot.node.img), after: footage(data, ids.after, after), node: after };
};

export default async (layer, beat, data) => {
  const { slots, show } = pair(layer, data, beat, 700, 350);
  const sides = Object.fromEntries(
    Object.keys(slots).map((key) => [key, layers(data, slots[key], { before: beat.clips.before[key], after: beat.clips.after[key] })]),
  );
  const title = el('h1', 'headline headline--center abs', layer, beat.title);
  const after = el('h1', 'headline headline--center abs', layer, beat.after);
  for (const node of [title, after]) node.style.fontSize = '52px';

  const { key, prefix, before, after: changed, suffix } = data.edit;
  const inserted = changed.slice(before.length - 1, -1);
  const card = el('div', 'card abs', layer);
  el('div', 'card__tab', card, beat.file);
  const pre = el('pre', 'code', card);
  pre.style.fontSize = '22px';
  const keyLine = el('span', 'code__line', pre);
  keyLine.innerHTML = json(key);
  keyLine.style.opacity = '0.55';
  const line = el('span', 'code__line', pre);
  const head = el('span', null, line);
  head.innerHTML = json(prefix + before.slice(0, -1));
  const typed = el('span', 'code-edit', line);
  const caret = el('span', 'code-caret', line);
  const tail = el('span', null, line);
  tail.innerHTML = json(`]${suffix}`);
  typed.innerHTML = json(inserted);
  card.style.width = 'max-content';
  let width = 0;

  const time = data.marks.tour[beat.hold] + beat.offset;
  const typeEnd = beat.editAt + 0.8;
  const swapAt = typeEnd + 0.35;

  return {
    update(t) {
      if (!width) {
        width = card.offsetWidth;
        card.style.width = `${width}px`;
      }
      show(t, 0);
      const count = Math.round(progress(t, beat.editAt, 0.8, (p) => p) * inserted.length);
      typed.innerHTML = json(inserted.slice(0, count));
      typed.style.background = count ? 'rgba(185, 163, 255, 0.22)' : 'transparent';
      const typing = t >= beat.editAt && t <= typeEnd;
      const blink = Math.floor(t * 2.5) % 2 === 0;
      caret.style.opacity = typing || (t > beat.editAt - 0.6 && t < swapAt + 0.5 && blink) ? '1' : '0';
      const swap = progress(t, swapAt, 0.6);
      place(title, { y: 70, opacity: progress(t, 0, 0.6) * (1 - swap) });
      place(after, { y: 70, opacity: swap });
      place(card, { x: (1920 - width) / 2, y: 160 + (1 - progress(t, 0.2, 0.7)) * 20, opacity: progress(t, 0.2, 0.7) });
      for (const side of Object.values(sides)) side.node.style.opacity = String(swap);
      return Promise.all(Object.values(sides).flatMap((side) => [side.before.at(time), side.after.at(time)]));
    },
  };
};
