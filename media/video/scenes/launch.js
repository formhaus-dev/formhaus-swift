import { footage } from './footage.js';
import { easeOut, el, mix, place, progress } from './kit.js';
import { pair } from './pair.js';

export default async (layer, beat, data) => {
  const next = data.beats[data.beats.findIndex((item) => item.id === beat.id) + 1];
  const { sides, frame, captionY, targetCaptionY } = pair(layer, data, next, { head: 144, height: 662, to: {} });
  const players = Object.entries(sides).map(([key, side]) => {
    const [script, mark] = next.sync[key];
    const from = data.marks[script][mark] + next.from;
    return { player: footage(data, next.clips[key], side.node.img, { cursor: next.cursor && key === 'web' }), from };
  });
  const title = el('h1', 'headline headline--center launch-title abs', layer);
  const words = beat.title.split(' ').map((word, index, all) => {
    const node = el('span', 'launch-word', title, word);
    if (index < all.length - 1) title.append(' ');
    return node;
  });
  const subline = el('p', 'sub launch-sub abs', layer, beat.subline);
  Object.assign(subline.style, { width: '1920px', textAlign: 'center' });
  const caption = el('div', 'caption abs', layer, next.caption);
  const handoff = beat.duration - 0.5;

  return {
    update(t) {
      const blend = progress(t, handoff, 0.5);
      frame((index) => ({ grow: mix(0.95, 1, progress(t, index * 0.06, handoff, easeOut)) }), blend);
      words.forEach((word, index) => {
        const p = progress(t, 0.1 + index * 0.07, 0.45, easeOut);
        word.style.opacity = String(p);
        word.style.transform = `translateY(${(1 - p) * 24}px)`;
      });
      const gone = progress(t, handoff, 0.22);
      place(title, { y: captionY - blend * 40, opacity: 1 - gone });
      const sub = progress(t, 0.65, 0.45, easeOut);
      place(subline, { y: captionY + 92 + (1 - sub) * 12 - blend * 40, opacity: sub * (1 - gone) });
      const show = progress(t, handoff + 0.25, 0.25);
      place(caption, { y: targetCaptionY + (1 - show) * 16, opacity: show });
      return Promise.all(players.map(({ player, from }) => player.at(from)));
    },
  };
};
