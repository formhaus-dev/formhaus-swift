import { footage } from './footage.js';
import { easeOut, el, mix, place, progress } from './kit.js';
import { pair } from './pair.js';

export default async (layer, beat, data) => {
  const { sides, frame, captionY } = pair(layer, data, beat, { head: 144, height: 662 });
  const stills = Object.entries(sides).map(([side, item]) => footage(data, beat.stills[side], item.node.img));
  const title = el('h1', 'headline headline--center launch-title abs', layer);
  const words = beat.title.split(' ').map((word, index, all) => {
    const node = el('span', 'launch-word', title, word);
    if (index < all.length - 1) title.append(' ');
    return node;
  });
  const subline = el('p', 'sub launch-sub abs', layer, beat.subline);
  Object.assign(subline.style, { width: '1920px', textAlign: 'center' });

  return {
    update(t) {
      frame((index) => ({ grow: mix(0.95, 1, progress(t, index * 0.06, beat.duration, easeOut)) }));
      words.forEach((word, index) => {
        const p = progress(t, 0.1 + index * 0.07, 0.45, easeOut);
        word.style.opacity = String(p);
        word.style.transform = `translateY(${(1 - p) * 24}px)`;
      });
      place(title, { y: captionY });
      const sub = progress(t, 0.65, 0.45, easeOut);
      place(subline, { y: captionY + 92 + (1 - sub) * 12, opacity: sub });
      return Promise.all(stills.map((still) => still.at(beat.at)));
    },
  };
};
