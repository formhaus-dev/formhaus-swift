import { twoUp } from './camera.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';

const captions = (layer, beat, marks) => {
  const steps = (beat.steps ?? []).map((step) => ({ at: marks[step.at] - beat.start0, node: el('div', 'caption caption--step abs', layer, step.text) }));
  const main = { at: beat.captionAt, node: el('div', 'caption abs', layer, beat.caption) };
  return [...steps, main];
};

export default async (layer, beat, data) => {
  const region = beat.labels ? { top: 130, height: 880 } : undefined;
  const { sides, frame } = twoUp(layer, data, beat, region);
  const clip = (key) => {
    const [script, mark] = beat.sync[key];
    const from = data.marks[script][mark] + beat.from + (beat.shift?.[key] ?? 0);
    return { player: footage(data, beat.clips[key], sides[key].node.img, { cursor: beat.cursor && key === 'web' }), from };
  };
  const clips = Object.fromEntries(Object.keys(sides).map((key) => [key, clip(key)]));
  const [script, mark] = beat.sync.web;
  const lines = captions(layer, { ...beat, start0: data.marks[script][mark] + beat.from }, data.marks[script]);
  const labels = Object.entries(beat.labels ?? {}).map(([key, text]) => ({ node: el('div', 'pill abs', layer, text), side: sides[key] }));

  return {
    update(t) {
      frame(t);
      lines.forEach((line, index) => {
        const next = lines[index + 1]?.at ?? Infinity;
        const shown = progress(t, line.at, 0.35) * (1 - progress(t, next - 0.3, 0.25));
        place(line.node, { y: 28 + (1 - progress(t, line.at, 0.35)) * 10, opacity: shown });
      });
      for (const { node, side } of labels) {
        place(node, { x: side.x + (side.node.width * side.scale - node.offsetWidth) / 2, y: 1020, opacity: 1 });
      }
      return Promise.all(Object.values(clips).map(({ player, from }) => player.at(from + t)));
    },
  };
};
