import { el } from './kit.js';

const lock =
  '<svg viewBox="0 0 12 14" aria-hidden="true"><rect x="1" y="6" width="10" height="7.5" rx="2" fill="currentColor"/><path d="M3.5 6V4.2a2.5 2.5 0 0 1 5 0V6" fill="none" stroke="currentColor" stroke-width="1.6"/></svg>';

const sized = (root, width, height, vars) => {
  for (const [name, value] of Object.entries(vars)) root.style.setProperty(name, `${value}px`);
  return { root, width, height };
};

const phone = (parent, spec, bezel, kind) => {
  const [w, h] = spec.screen;
  const root = el('div', `device ${kind}`, parent);
  for (const name of ['action', 'up', 'down', 'power']) el('i', `${kind}__button ${kind}__button--${name}`, root);
  const screen = el('div', 'device__screen', root);
  const img = el('img', null, screen);
  img.alt = '';
  return { ...sized(root, w + bezel * 2, h + bezel * 2, { '--w': w, '--h': h, '--r': spec.radius, '--bezel': bezel }), img, screen };
};

const browser = (parent, spec, { frame = false } = {}) => {
  const [w, h] = spec.viewport;
  const bar = 44;
  const root = el('div', 'device browser', parent);
  const top = el('div', 'browser__bar', root);
  const dots = el('span', 'browser__dots', top);
  for (let index = 0; index < 3; index += 1) el('i', null, dots);
  const url = el('span', 'browser__url', top);
  url.innerHTML = lock;
  el('span', null, url, spec.url);
  const screen = el('div', 'device__screen', root);
  const media = el(frame ? 'iframe' : 'img', null, screen);
  if (!frame) media.alt = '';
  return { ...sized(root, w + 2, h + bar + 2, { '--w': w, '--h': h }), img: media, screen };
};

const mac = (parent, spec) => {
  const [w, h] = spec.window;
  const bar = 52;
  const root = el('div', 'device mac', parent);
  const top = el('div', 'mac__bar', root);
  const dots = el('span', 'mac__dots', top);
  for (let index = 0; index < 3; index += 1) el('i', null, dots);
  el('span', 'mac__title', top, spec.title);
  const screen = el('div', 'device__screen', root);
  const img = el('img', null, screen);
  img.alt = '';
  return { ...sized(root, w + 2, h + bar + 2, { '--w': w, '--h': h }), img, screen };
};

export const device = (parent, spec, options) => {
  if (spec.kind === 'mac') return mac(parent, spec);
  if (spec.kind === 'iphone') return phone(parent, spec, 14, 'iphone');
  return browser(parent, spec, options);
};
