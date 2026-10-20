import { clamp } from './kit.js';

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

export const footage = (data, id, img) => {
  const info = data.footage[id];
  if (!info) throw new Error(`Missing footage ${id}. Run record.sh first.`);
  const show = (src) => {
    if (img.getAttribute('src') !== src) img.setAttribute('src', src);
    return decode(img);
  };
  return {
    info,
    at(seconds) {
      if (info.still) return show(`footage/frames/${id}/still.png`);
      const index = clamp(Math.round(warp(info.marks, seconds) * info.rate), 0, info.count - 1) + 1;
      return show(`footage/frames/${id}/${String(index).padStart(5, '0')}.jpg`);
    },
  };
};
