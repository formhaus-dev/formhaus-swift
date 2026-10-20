import { json } from './code.js';
import { device } from './devices.js';
import { el, motion, place, progress, rise } from './kit.js';

const selectors = {
  title: 'h1',
  description: '.lead',
  step: '.fh-step-progress',
  label: '.fh-field__label',
  actions: '.fh-form-actions',
};

const loaded = (frame) =>
  new Promise((done) => {
    const check = () => {
      const doc = frame.contentDocument;
      if (doc?.documentElement.dataset.ready === 'true' && doc.querySelector('.fh-form-actions')) {
        const images = [...doc.querySelectorAll('.fh-field__option-image')];
        const settled = (img) => img.complete || new Promise((ready) => img.addEventListener('load', ready, { once: true }));
        doc.fonts.ready.then(() => Promise.all(images.map(settled))).then(done);
      } else setTimeout(check, 30);
    };
    check();
  });

const findTarget = (doc, target) => {
  const [name, index] = target.split(':');
  return name === 'option' ? doc.querySelectorAll('.fh-field__radio-option')[Number(index)] : doc.querySelector(selectors[name]);
};

export default async (layer, beat, data) => {
  const group = el('div', 'abs', layer);
  group.style.width = '1920px';
  group.style.height = '1080px';
  const title = el('h1', 'headline abs', group, beat.title);
  const sub = el('p', 'sub abs', group, beat.subtitle);
  const after = el('p', 'sub abs', group, beat.after);

  const card = el('div', 'card abs', group);
  card.style.width = '900px';
  el('div', 'card__tab', card, 'project-inquiry.json');
  const pre = el('pre', 'code', card);
  pre.style.fontSize = '17px';
  const lines = data.excerpt.map((line) => {
    const node = el('span', 'code__line', pre);
    node.innerHTML = json(line.text) || ' ';
    return { node, target: line.target };
  });

  const spec = data.devices[beat.device];
  const browser = device(group, spec, { frame: true });
  const scale = 825 / browser.height;
  const x = 1920 - 136 - browser.width * scale;
  browser.img.src = 'web/dist/index.html?def=base';
  await loaded(browser.img);
  const doc = browser.img.contentDocument;
  const order = ['title', 'description', 'step', 'label', ...data.excerpt.filter((l) => l.target?.startsWith('option')).map((l) => l.target), 'actions'];
  const parts = order.map((target) => ({ target, node: findTarget(doc, target) }));
  for (const { node } of parts) node.style.willChange = 'opacity, transform';

  return {
    update(t) {
      const push = 1 + progress(t, 0, beat.duration, (p) => p) * 0.02 * motion.scale;
      group.style.transform = `scale(${push})`;
      group.style.transformOrigin = '960px 540px';
      rise(title, t, 0.1, { x: 120, y: 92 });
      const swap = progress(t, 2.7, 0.5);
      sub.style.opacity = String(rise(sub, t, 0.35, { x: 122, y: 178 }) * (1 - swap));
      place(after, { x: 122, y: 178, opacity: swap });
      rise(card, t, 0.35, { length: 0.8, distance: 30, x: 120, y: 262 });
      lines.forEach(({ node }, index) => {
        node.style.opacity = String(progress(t, 0.7 + index * 0.075, 0.3));
      });
      const shown = progress(t, 2.3, 0.7);
      place(browser.root, { x, y: 128 + (1 - shown) * 30 * motion.scale, scale, opacity: shown });
      parts.forEach(({ target, node }, index) => {
        const at = 2.8 + index * 0.19;
        const p = progress(t, at, 0.5);
        node.style.opacity = String(p);
        node.style.transform = `translateY(${(1 - p) * 14 * motion.scale}px)`;
        const line = lines.find((item) => item.target === target);
        if (line) {
          const glow = progress(t, at - 0.1, 0.2) * (1 - progress(t, at + 0.45, 0.5));
          line.node.style.background = `rgba(185, 163, 255, ${0.22 * glow})`;
        }
      });
    },
  };
};
