import { footage } from './footage.js';
import { easeOut, el, place, progress } from './kit.js';
import { pair } from './pair.js';

export default async (layer, beat, data) => {
  const { sides, frame } = pair(layer, data, beat, { gap: 48, top: 290, height: 742 });
  const stills = Object.entries(sides).map(([side, item]) => footage(data, beat.stills[side], item.node.img));
  const title = el('h1', 'headline headline--center launch-title abs', layer, beat.title);
  const subline = el('p', 'sub launch-sub abs', layer, beat.subline);
  subline.style.width = '1920px';
  subline.style.textAlign = 'center';

  return {
    update(t) {
      frame(t);
      place(title, { y: 96 + (1 - progress(t, 0, 0.8, easeOut)) * 8 });
      place(subline, { y: 186, opacity: progress(t, 0.3, 0.5) });
      return Promise.all(stills.map((still) => still.at(beat.at)));
    },
  };
};
