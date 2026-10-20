import { json } from './code.js';
import { el } from './kit.js';

export const jsonCard = (parent, data, size = 17) => {
  const card = el('div', 'card abs', parent);
  el('div', 'card__tab', card, data.excerptFile);
  const pre = el('pre', 'code', card);
  pre.style.fontSize = `${size}px`;
  const lines = data.excerpt.map((line) => {
    const node = el('span', 'code__line', pre);
    node.innerHTML = json(line.text) || ' ';
    return node;
  });
  return { card, lines };
};
