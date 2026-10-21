import { footage } from './footage.js';
import { el, place, progress, softIn } from './kit.js';
import { pair } from './pair.js';

export default async (layer, beat, data) => {
  const { sides, frame, captionY } = pair(layer, data, beat);
  const players = Object.entries(sides).map(([key, side]) => {
    const [script, mark] = beat.sync[key];
    const from = data.marks[script][mark] + beat.from;
    return { player: footage(data, beat.clips[key], side.node.img, { cursor: beat.cursor && key === 'web' }), from };
  });
  const caption = el('div', 'caption abs', layer, beat.caption);
  const index = data.beats.findIndex((item) => item.id === beat.id);
  const fadesIn = beat.continues && data.beats[index - 1].scene === beat.scene && data.beats[index - 1].caption !== beat.caption;
  const fadesOut = data.beats[index + 1]?.continues && data.beats[index + 1].caption !== beat.caption;

  return {
    update(t) {
      frame();
      const shown = fadesOut ? 1 - progress(t, beat.duration - 0.2, 0.2) : 1;
      place(caption, { y: captionY, opacity: shown });
      if (fadesIn) softIn(caption, t, 0.05, shown);
      return Promise.all(players.map(({ player, from }) => player.at(from + t)));
    },
  };
};
