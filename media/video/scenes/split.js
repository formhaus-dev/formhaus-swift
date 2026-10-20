import { footage } from './footage.js';
import { el, place } from './kit.js';
import { pair } from './pair.js';

export default async (layer, beat, data) => {
  const { sides, frame } = pair(layer, data, beat);
  const players = Object.entries(sides).map(([key, side]) => {
    const [script, mark] = beat.sync[key];
    const from = data.marks[script][mark] + beat.from;
    return { player: footage(data, beat.clips[key], side.node.img, { cursor: beat.cursor && key === 'web' }), from };
  });
  const caption = el('div', 'caption abs', layer, beat.caption);

  return {
    update(t) {
      frame(t);
      place(caption, { y: 96 });
      return Promise.all(players.map(({ player, from }) => player.at(from + t)));
    },
  };
};
