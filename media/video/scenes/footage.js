import { clamp, el } from './kit.js';

const decode = (img) => (img.complete && img.naturalWidth ? Promise.resolve() : img.decode().catch(() => {}));

const warp = (marks, seconds) => {
  const points = [[0, 0], ...marks];
  const after = points.findIndex(([script]) => script > seconds);
  if (after === -1) {
    const [script, clip] = points.at(-1);
    return clip + seconds - script;
  }
  const [a, b] = [points[after - 1], points[after]];
  return a[1] + ((seconds - a[0]) / (b[0] - a[0])) * (b[1] - a[1]);
};

const press = 0.16;
const release = 0.36;

const touches = (taps, parent) =>
  taps.map((tap) => {
    const node = el('i', 'touch', parent);
    node.style.left = `${tap.x * 100}%`;
    node.style.top = `${tap.y * 100}%`;
    return { node, at: tap.time - (tap.kind === 'type' ? 0.3 : 0) };
  });

const showTouch = ({ node, at }, time, rate) => {
  const offset = (time - at) / rate;
  const visible = offset > -press && offset < release;
  node.style.display = visible ? 'block' : 'none';
  if (!visible) return;
  const down = clamp((offset + press) / press);
  const up = clamp(offset / release);
  node.style.opacity = String(Math.min(down, 1 - up));
  node.style.transform = `translate(-50%, -50%) scale(${offset < 0 ? 1.35 - 0.35 * down : 1 + 0.25 * up})`;
};

export const footage = (data, id, img) => {
  const info = data.footage[id];
  if (!info) throw new Error(`Missing footage ${id}. Run record.sh first.`);
  const marks = touches(info.taps ?? [], img.parentElement);
  const show = (src) => {
    if (img.getAttribute('src') !== src) img.setAttribute('src', src);
    return decode(img);
  };
  return {
    info,
    at(seconds, rate = 1) {
      if (info.still) return show(`footage/frames/${id}/still.png`);
      const time = warp(info.marks, seconds);
      for (const mark of marks) showTouch(mark, time, rate);
      const index = clamp(Math.round(time * info.rate), 0, info.count - 1) + 1;
      return show(`footage/frames/${id}/${String(index).padStart(5, '0')}.jpg`);
    },
  };
};
