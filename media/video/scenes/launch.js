import { twoUp } from './camera.js';
import { footage } from './footage.js';
import { easeOut, el, place, progress } from './kit.js';

export default async (layer, beat, data) => {
  const { sides, frame } = twoUp(layer, data, beat, { top: 196, height: 1000 }, 70);
  const stills = Object.entries(sides).map(([side, item]) => footage(data, beat.stills[side], item.node.img));
  const title = el('h1', 'headline headline--center launch-title abs', layer, beat.title);
  const subline = el('p', 'sub launch-sub abs', layer, beat.subline);
  subline.style.width = '1920px';
  subline.style.textAlign = 'center';

  return {
    update(t) {
      frame(t);
      place(title, { y: 22 + (1 - progress(t, 0.9, 0.8, easeOut)) * 20, opacity: progress(t, 0.9, 0.6) });
      place(subline, { y: 122, opacity: progress(t, 1.4, 0.6) });
      return Promise.all(stills.map((still) => still.at(beat.at)));
    },
  };
};
