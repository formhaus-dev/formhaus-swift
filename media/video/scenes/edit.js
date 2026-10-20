import { json } from './code.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';
import { pair } from './pair.js';

const codeCard = (layer, beat, data) => {
  const { open, key, before, after, rest, close } = data.edit;
  const card = el('div', 'card abs', layer);
  el('div', 'card__tab', card, beat.file).style.fontSize = '28px';
  const pre = el('pre', 'code', card);
  pre.style.fontSize = '40px';
  pre.style.padding = '16px 48px 32px';
  const line = (text) => {
    const node = el('span', 'code__line', pre);
    node.innerHTML = json(text);
    return node;
  };
  line(open);
  const edited = el('span', 'code__line', pre);
  el('span', null, edited).innerHTML = json(key);
  const value = el('span', 'code-edit', edited);
  const caret = el('span', 'code-caret', edited);
  el('span', null, edited).innerText = ',';
  for (const text of rest) line(text);
  line(close);
  return { card, edited, value, caret, before, after };
};

const typed = (code, t, start, length) => {
  const half = length / 2;
  const deleting = progress(t, start, half, (p) => p);
  if (deleting < 1) return code.before.slice(0, Math.round(code.before.length * (1 - deleting)));
  return code.after.slice(0, Math.round(code.after.length * progress(t, start + half, half, (p) => p)));
};

export default async (layer, beat, data) => {
  const { sides, frame } = pair(layer, data, beat);
  const players = Object.entries(sides).map(([key, side]) => {
    const [script, mark] = beat.sync[key];
    return { player: footage(data, beat.clips[key], side.node.img, { cursor: beat.cursor && key === 'web' }), from: data.marks[script][mark] + beat.from };
  });
  const title = el('div', 'caption abs', layer, beat.title);
  const code = codeCard(layer, beat, data);
  const typeEnd = beat.editAt + 0.8;

  return {
    update(t) {
      frame(t);
      place(title, { y: 96 });
      const text = typed(code, t, beat.editAt, 0.8);
      code.value.innerHTML = json(text);
      code.value.style.background = t >= typeEnd - 0.4 ? 'rgba(185, 163, 255, 0.28)' : 'transparent';
      code.edited.style.background = `rgba(185, 163, 255, ${0.16 * progress(t, beat.editAt - 0.3, 0.3)})`;
      code.caret.style.opacity = t >= beat.editAt - 0.4 && t <= typeEnd + 0.2 ? '1' : '0';
      const devices = t >= beat.cutAt;
      place(code.card, { x: (1920 - code.card.offsetWidth) / 2, y: 623 - code.card.offsetHeight / 2 + (1 - progress(t, 0, 0.35)) * 40, opacity: devices ? 0 : 1 });
      for (const side of Object.values(sides)) side.node.root.style.visibility = devices ? 'visible' : 'hidden';
      return Promise.all(players.map(({ player, from }) => player.at(from + Math.max(0, t - beat.cutAt))));
    },
  };
};
