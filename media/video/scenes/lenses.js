import { twoUp } from './camera.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';
import { lens } from './lens.js';

const gap = 60;

export default async (layer, beat, data) => {
  const { sides, frame } = twoUp(layer, data, beat);
  const [script, mark] = beat.sync.web;
  const start = data.marks[script][mark] + beat.from;
  const players = Object.keys(sides).map((key) =>
    footage(data, beat.clips[key], sides[key].node.img, { cursor: beat.cursor && key === 'web' }),
  );
  const lenses = Object.keys(sides).map((key) => ({
    ...lens(layer, data, { device: beat.devices[key], clips: [beat.clips[key]], ...beat.lenses[key] }),
    label: el('div', 'pill abs', layer, beat.lenses[key].label),
  }));
  const step = beat.step && el('div', 'caption caption--step abs', layer, beat.step.text);
  const caption = el('div', 'caption abs', layer, beat.caption);
  const total = lenses.reduce((sum, item) => sum + item.width, 0) + gap * (lenses.length - 1);
  const height = lenses[0].height;
  const top = 214 + (818 - height - 84) / 2;
  const stepAt = beat.step ? data.marks[script][beat.step.at] - start : 0;
  const freeze = data.marks[script][beat.freeze.at] + beat.freeze.offset;

  return {
    update(t) {
      frame(t);
      const out = progress(t, beat.lensAt - 0.3, 0.3);
      const zoom = progress(t, beat.lensAt, 0.4);
      for (const item of Object.values(sides)) item.node.root.style.opacity = String(1 - out);
      lenses.forEach((item, index) => {
        const x = (1920 - total) / 2 + index * (item.width + gap);
        place(item.card, { x, y: top + (1 - zoom) * 30, opacity: zoom });
        place(item.label, { x: x + (item.width - item.label.offsetWidth) / 2, y: top + height + 28, opacity: zoom });
      });
      if (step) place(step, { y: 96, opacity: progress(t, stepAt, 0.35) * (1 - progress(t, beat.captionAt - 0.3, 0.25)) });
      place(caption, { y: 96, opacity: progress(t, beat.captionAt, 0.35) });
      const frozen = Math.min(start + t, freeze);
      return Promise.all([
        ...players.map((player) => player.at(start + t)),
        ...lenses.flatMap((item) => item.players.map(({ player }) => player.at(frozen))),
      ]);
    },
  };
};
