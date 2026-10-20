import { json } from './code.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';
import { pair } from './pair.js';

const codeCard = (layer, beat, data) => {
  const { key, prefix, before, after, suffix } = data.edit;
  const card = el('div', 'card abs', layer);
  el('div', 'card__tab', card, beat.file).style.fontSize = '28px';
  const pre = el('pre', 'code', card);
  pre.style.fontSize = '40px';
  pre.style.padding = '16px 48px 32px';
  const keyLine = el('span', 'code__line', pre);
  keyLine.innerHTML = json(key);
  keyLine.style.opacity = '0.55';
  const edited = el('span', 'code__line', pre);
  el('span', null, edited).innerHTML = json(prefix);
  const value = el('span', 'code-edit', edited);
  const caret = el('span', 'code-caret', edited);
  el('span', null, edited).innerHTML = json(suffix);
  return { card, edited, value, caret, before, after };
};

const typed = (code, t, start, length) => {
  const half = length / 2;
  const deleting = progress(t, start, half, (p) => p);
  if (deleting < 1) return code.before.slice(0, Math.round(code.before.length * (1 - deleting)));
  return code.after.slice(0, Math.round(code.after.length * progress(t, start + half, half, (p) => p)));
};

export default async (layer, beat, data) => {
  const { sides, frame, captionY, middle } = pair(layer, data, beat);
  const players = Object.entries(sides).map(([key, side]) => {
    const after = side.node.img.cloneNode();
    side.node.screen.append(after);
    Object.assign(after.style, { position: 'absolute', inset: '0' });
    const [script, mark] = beat.sync;
    const from = data.marks[script][mark] + beat.from;
    const cursor = beat.cursor && key === 'web';
    return {
      img: after,
      from,
      before: footage(data, beat.clips.before[key], side.node.img, { cursor }),
      after: footage(data, beat.clips.after[key], after, { cursor }),
    };
  });
  const title = el('div', 'caption abs', layer, beat.title);
  const code = codeCard(layer, beat, data);
  const [codeAt, afterAt] = beat.cuts;

  return {
    update(t) {
      frame();
      place(title, { y: captionY });
      const showCode = t >= codeAt && t < afterAt;
      const local = t - codeAt;
      code.value.innerHTML = json(typed(code, local, 0.2, 0.7));
      code.value.style.background = local >= 0.6 ? 'rgba(185, 163, 255, 0.28)' : 'transparent';
      code.edited.style.background = `rgba(185, 163, 255, ${0.16 * progress(local, 0, 0.2)})`;
      code.caret.style.opacity = local >= 0 && local <= 1.0 ? '1' : '0';
      place(code.card, { x: (1920 - code.card.offsetWidth) / 2, y: middle - code.card.offsetHeight / 2 + (1 - progress(local, 0, 0.3)) * 40, opacity: showCode ? 1 : 0 });
      for (const side of Object.values(sides)) side.node.root.style.opacity = showCode ? '0.3' : '1';
      const after = t >= afterAt;
      return Promise.all(
        players.map((player) => {
          player.img.style.opacity = after ? '1' : '0';
          return after ? player.after.at(player.from + t - afterAt) : player.before.at(player.from + Math.min(t, codeAt));
        }),
      );
    },
  };
};
