export const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));
export const mix = (a, b, t) => a + (b - a) * t;
export const easeInOut = (t) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);
export const easeOut = (t) => 1 - (1 - t) ** 3;
export const progress = (t, start, length, ease = easeInOut) => ease(clamp((t - start) / length));

export const motion = { scale: 1 };

const short = /(?<=^|\s)(in|on|and|of|the|a|for|to|with)\s+/gi;

export const bind = (text) => text.replace(short, (_, word) => `${word}\u00a0`);

export const el = (tag, className, parent, text) => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = bind(text);
  parent?.append(node);
  return node;
};

export const place = (node, { x = 0, y = 0, scale = 1, opacity = 1 }) => {
  node.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
  node.style.opacity = String(opacity);
};

export const captionHeight = 70;
export const safeTop = 96;
const shadowed = 34;

export const stack = (parts, optical = shadowed) => {
  const total = parts.reduce((sum, [height, gap = 0]) => sum + height + gap, 0);
  let y = Math.max(safeTop, (1080 - total - optical) / 2);
  return parts.map(([height, gap = 0]) => {
    const top = y;
    y += height + gap;
    return top;
  });
};
