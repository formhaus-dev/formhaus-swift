import { source } from './code.js';
import { el } from './kit.js';

const lineHeight = 26 * 1.6;
const width = 1400;
const gap = 22;
const top = 40;

export const codePanels = (layer, beat) => {
  let y = top;
  return beat.panels.map((panel) => {
    const card = el('div', 'card abs code-panel', layer);
    card.style.width = `${width}px`;
    el('div', 'card__tab', card, panel.file);
    const pre = el('pre', 'code', card);
    const lines = panel.lines.map((text) => {
      const node = el('span', 'code__line', pre);
      node.innerHTML = source(text, panel.language) || ' ';
      return node;
    });
    const marker = el('span', 'drift-marker', card, panel.drift.marker);
    marker.style.top = `${44 + 22 + (panel.drift.line - 1) * lineHeight}px`;
    const height = 44 + 22 + lines.length * lineHeight + 28;
    const placed = { card, lines, marker, drift: panel.drift, x: (1920 - width) / 2, y, width, height };
    y += height + gap;
    return placed;
  });
};
