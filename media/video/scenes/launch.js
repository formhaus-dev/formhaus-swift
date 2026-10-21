import { json } from './code.js';
import { footage } from './footage.js';
import { easeOut, el, mix, place, progress } from './kit.js';
import { pair } from './pair.js';

const codeCard = (layer, beat) => {
  const card = el('div', 'card abs', layer);
  el('div', 'card__tab launch-tab', card, beat.file);
  const pre = el('pre', 'code launch-code', card);
  const lines = beat.code.map((line) => {
    const node = el('span', 'code__line', pre);
    node.innerHTML = json(line);
    return node;
  });
  return { card, lines };
};

const rise = (node, t, start, distance) => {
  const p = progress(t, start, 0.4, easeOut);
  node.style.opacity = String(p);
  node.style.transform = `translateY(${(1 - p) * distance}px)`;
};

export default async (layer, beat, data) => {
  const next = data.beats[data.beats.findIndex((item) => item.id === beat.id) + 1];
  const { sides, frame, captionY } = pair(layer, data, next);
  const players = Object.entries(sides).map(([key, side]) => {
    const [script, mark] = next.sync[key];
    const from = data.marks[script][mark] + next.from;
    return { player: footage(data, next.clips[key], side.node.img, { cursor: next.cursor && key === 'web' }), from };
  });
  const { card, lines } = codeCard(layer, beat);
  const head = el('div', 'abs launch-head', layer);
  const title = el('h1', 'headline headline--center launch-title', head);
  const words = beat.title.split(' ').map((word, index, all) => {
    const node = el('span', 'launch-word', title, word);
    if (index < all.length - 1) title.append(' ');
    return node;
  });
  const subline = el('p', 'sub launch-sub', head, beat.subline);
  const caption = el('div', 'caption abs', layer, next.caption);
  const { code, build, title: titleAt, devices } = beat.timing;

  return {
    update(t) {
      const out = progress(t, build, 0.35);
      const shrink = mix(1, 0.8, out);
      place(card, {
        x: 960 - (card.offsetWidth * shrink) / 2,
        y: 540 - (card.offsetHeight * shrink) / 2,
        scale: shrink,
        opacity: 1 - out,
      });
      lines.forEach((line, index) => rise(line, t, (index * code) / lines.length, 12));
      words.forEach((word, index) => rise(word, t, titleAt + index * 0.07, 28));
      rise(subline, t, titleAt + 0.45, 16);
      const leave = progress(t, devices - 0.3, 0.3);
      place(head, { y: 540 - head.offsetHeight / 2 - leave * 120, opacity: 1 - leave });
      frame((index) => {
        const p = progress(t, devices + 0.1 + index * 0.08, 0.55, easeOut);
        return { rise: (1 - p) * 140, grow: mix(0.92, 1, p), opacity: p };
      });
      place(caption, { y: captionY + (1 - progress(t, devices + 0.3, 0.4, easeOut)) * 16, opacity: progress(t, devices + 0.3, 0.4) });
      return Promise.all(players.map(({ player, from }) => player.at(from)));
    },
  };
};
