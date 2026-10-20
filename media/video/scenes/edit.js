import { json } from './code.js';
import { el, place, progress } from './kit.js';
import { lens } from './lens.js';

const gap = 60;

export default async (layer, beat, data) => {
  const sides = Object.keys(beat.lenses).map((key) =>
    lens(layer, data, { device: beat.devices[key], clips: [beat.clips.before[key], beat.clips.after[key]], fade: key === 'ios' ? 'both' : true, ...beat.lenses[key] }),
  );
  const total = sides.reduce((sum, item) => sum + item.width, 0) + gap;
  const title = el('div', 'caption abs', layer, beat.title);
  const after = el('div', 'caption abs', layer, beat.after);

  const { key, prefix, before, after: changed, suffix } = data.edit;
  const inserted = changed.slice(before.length - 1, -1);
  const card = el('div', 'card abs', layer);
  el('div', 'card__tab', card, beat.file).style.fontSize = '26px';
  const pre = el('pre', 'code', card);
  pre.style.fontSize = '32px';
  pre.style.padding = '14px 32px 22px';
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
      let x = (1920 - total) / 2;
      for (const side of sides) {
        place(side.card, { x, y: 1032 - side.height, opacity: progress(t, 0.1, 0.6) });
        x += side.width + gap;
      }
      const count = Math.round(progress(t, beat.editAt, 0.8, (p) => p) * inserted.length);
      typed.innerHTML = json(inserted.slice(0, count));
      typed.style.background = count ? 'rgba(185, 163, 255, 0.28)' : 'transparent';
      line.style.background = `rgba(185, 163, 255, ${0.16 * progress(t, beat.editAt - 0.3, 0.3)})`;
      const typing = t >= beat.editAt && t <= typeEnd;
      const blink = Math.floor(t * 2.5) % 2 === 0;
      caret.style.opacity = typing || (t > beat.editAt - 0.6 && t < swapAt + 0.5 && blink) ? '1' : '0';
      const swap = progress(t, swapAt, 0.6);
      place(title, { y: 96, opacity: progress(t, 0, 0.6) * (1 - swap) });
      place(after, { y: 96, opacity: swap });
      place(card, { x: (1920 - width) / 2, y: 214 + (1 - progress(t, 0.2, 0.7)) * 20, opacity: progress(t, 0.2, 0.7) });
      for (const side of sides) side.players[1].img.style.opacity = String(swap);
      return Promise.all(sides.flatMap((side) => side.players.map(({ player }) => player.at(time))));
    },
  };
};
