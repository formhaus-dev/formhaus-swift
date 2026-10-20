import { el, motion, place, progress } from './kit.js';

const rowHeight = 50;
const listHeight = 860;

export default async (layer, beat, data) => {
  const { count, names } = data.conformance;
  const number = el('div', 'proof-number abs', layer);
  const label = el('div', 'proof-label abs', layer, beat.count);
  const engines = el('div', 'chips proof-engines abs', layer);
  for (const name of beat.engines) el('span', 'chip chip--on', engines, `${name} ✓`);

  const list = el('div', 'proof-list abs', layer);
  const head = el('div', 'proof-row proof-row--head', list);
  el('span', null, head, beat.header);
  for (const name of beat.engines) el('b', null, head, name);
  const viewport = el('div', 'proof-viewport', list);
  const rows = el('div', null, viewport);
  const checks = names.map((name) => {
    const row = el('div', 'proof-row', rows);
    el('span', null, row, name);
    return beat.engines.map(() => el('i', null, row, '✓'));
  });
  const visibleRows = Math.floor(listHeight / rowHeight);
  const travel = names.length * rowHeight - (listHeight - 60);

  return {
    update(t) {
      const counted = Math.max(1, Math.round(progress(t, 0, beat.duration - 0.6) * count));
      number.textContent = String(counted);
      place(number, { x: 140, y: 170, opacity: progress(t, 0, 0.5) });
      place(label, { x: 150, y: 520, opacity: progress(t, 0, 0.4) });
      place(engines, { x: 150, y: 700, opacity: progress(t, 0.6, 0.5) });
      place(list, { x: 1040, y: 110, opacity: 0.5 * progress(t, 0.1, 0.6) });
      if (motion.scale) {
        rows.style.transform = `translateY(${-progress(t, 0.3, beat.duration - 0.8) * travel}px)`;
        return;
      }
      checks.slice(0, visibleRows).forEach((pair, row) => {
        pair.forEach((check, column) => {
          check.style.opacity = String(progress(t, 0.4 + row * 0.12 + column * 0.06, 0.2));
        });
      });
    },
  };
};
