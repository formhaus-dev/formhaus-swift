import { codePanels } from './codepanels.js';
import { easeOut, el, motion, place, progress } from './kit.js';

export const driftShown = (panel, t) => {
  const shown = progress(t, panel.drift.at, 0.35, easeOut);
  panel.lines[panel.drift.line - 1].style.background = `rgba(242, 115, 106, ${0.16 * shown})`;
  panel.marker.style.opacity = String(shown);
  panel.marker.style.transform = `translateX(${(1 - shown) * 12}px)`;
};

export default async (layer, beat) => {
  const panels = codePanels(layer, beat);
  const caption = el('div', 'caption abs', layer, beat.caption);
  const bottom = panels.at(-1).y + panels.at(-1).height;

  return {
    update(t) {
      panels.forEach((panel, index) => {
        const enter = progress(t, 0.1 + index * 0.14, 0.7, easeOut);
        place(panel.card, { x: panel.x + (1 - enter) * 90 * motion.scale, y: panel.y, opacity: enter });
        driftShown(panel, t);
      });
      const fadeOut = 1 - progress(t, beat.duration - 0.35, 0.3);
      place(caption, { y: bottom + 34 + (1 - progress(t, 2.5, 0.6)) * 12, opacity: progress(t, 2.5, 0.6) * fadeOut });
    },
  };
};
