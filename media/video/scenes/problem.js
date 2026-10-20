import { device } from './devices.js';
import { clamp, el, place, progress } from './kit.js';

const rowHeight = 620;
const gap = 80;

const mock = (screen, beat, entry) => {
  const root = el('div', `mock mock--${entry.device}`, screen);
  el('div', 'mock__title', root, beat.form.title);
  for (const name of [beat.form.email, beat.form.password]) {
    el('div', 'mock__label', root, name);
    el('div', 'mock__input', root);
  }
  const error = el('div', 'mock__error', root, entry.message);
  const button = el('div', 'mock__button', root, beat.form.button);
  const touch = el('i', 'touch', button);
  const alert = el('div', 'mock__alert', root);
  el('b', null, alert, entry.message);
  el('span', null, alert, 'OK');
  const pass = el('div', 'mock__pass', root);
  el('b', null, pass, '✓');
  el('span', null, pass, entry.message);
  return { error, touch, alert, pass, root };
};

export default async (layer, beat, data) => {
  const items = beat.screens.map((entry) => {
    const node = device(layer, data.devices[entry.device]);
    node.img.remove();
    const label = el('div', 'label abs', layer, entry.label);
    return { entry, node, label, scale: rowHeight / node.height, parts: mock(node.screen, beat, entry) };
  });
  const width = items.reduce((sum, item) => sum + item.node.width * item.scale, 0) + gap * (items.length - 1);
  let x = (1920 - width) / 2;
  const caption = el('div', 'caption abs', layer, beat.caption);

  for (const item of items) {
    item.x = x;
    item.width = item.node.width * item.scale;
    x += item.width + gap;
  }

  return {
    update(t) {
      items.forEach((item, index) => {
        const shown = progress(t, index * 0.1, 0.6);
        const y = 150 + rowHeight - item.node.height * item.scale;
        place(item.node.root, { x: item.x, y: y + (1 - shown) * 20, scale: item.scale, opacity: shown });
        item.label.style.width = `${item.width}px`;
        item.label.style.textAlign = 'center';
        place(item.label, { x: item.x, y: 104, opacity: progress(t, 0.3, 0.5) });
        const offset = t - beat.pressAt;
        const { touch, error, alert, pass } = item.parts;
        touch.style.display = offset > -0.16 && offset < 0.36 ? 'block' : 'none';
        touch.style.opacity = String(Math.min(clamp((offset + 0.16) / 0.16), 1 - clamp(offset / 0.36)));
        const result = progress(t, beat.pressAt + 0.08, 0.25);
        error.style.opacity = item.entry.result === 'error' ? String(result) : '0';
        alert.style.opacity = item.entry.result === 'alert' ? String(result) : '0';
        pass.style.opacity = item.entry.result === 'pass' ? String(result) : '0';
      });
      place(caption, { y: 860 + (1 - progress(t, 2.1, 0.6)) * 14, opacity: progress(t, 2.1, 0.6) });
    },
  };
};
