import { footage } from './footage.js';
import { el, place, progress } from './kit.js';
import { pair } from './pair.js';

export default async (layer, beat, data) => {
  const { sides, frame, captionY } = pair(layer, data, beat);
  const players = Object.entries(sides).map(([key, side]) => {
    const [script, mark] = beat.sync[key];
    const from = data.marks[script][mark] + beat.from;
    return { player: footage(data, beat.clips[key], side.node.img, { cursor: beat.cursor && key === 'web' }), from };
  });
  const caption = el('div', 'caption abs', layer, beat.caption);

  return {
    update(t) {
      frame();
      const enter = beat.continues ? 1 : progress(t, data.output.transition, 0.25);
      place(caption, { y: captionY, opacity: Math.min(enter, 1 - progress(t, beat.duration - 0.2, 0.2)) });
      return Promise.all(players.map(({ player, from }) => player.at(from + t)));
    },
  };
};
