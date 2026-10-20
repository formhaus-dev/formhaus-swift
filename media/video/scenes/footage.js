import { clamp, easeInOut, el } from './kit.js';

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

const arrow =
  '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 3l14 8-6 1.5L10 19z" fill="#0d0d15" stroke="#fff" stroke-width="1.5" stroke-linejoin="round"/></svg>';

const pointer = (taps, parent) => {
  const node = el('i', 'pointer', parent);
  node.innerHTML = arrow;
  return (time) => {
    const index = taps.findLastIndex((tap) => time >= tap.time - 0.4);
    const target = taps[Math.max(index, 0)];
    const from = taps[Math.max(index - 1, 0)];
    const move = index <= 0 ? 1 : easeInOut(clamp((time - target.time + 0.4) / 0.35));
    node.style.left = `${(from.x + (target.x - from.x) * move) * 100}%`;
    node.style.top = `${(from.y + (target.y - from.y) * move) * 100}%`;
    node.style.opacity = String(clamp((time - taps[0].time + 0.9) / 0.3));
  };
};

export const footage = (data, id, img, { cursor = false } = {}) => {
  const info = data.footage[id];
  if (!info) throw new Error(`Missing footage ${id}. Run record.sh first.`);
  const marks = touches(info.taps ?? [], img.parentElement);
  const point = cursor && info.taps?.length ? pointer(info.taps, img.parentElement) : null;
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
      point?.(time);
      const index = clamp(Math.round(time * info.rate), 0, info.count - 1) + 1;
      return show(`footage/frames/${id}/${String(index).padStart(5, '0')}.jpg`);
    },
  };
};
