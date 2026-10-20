export const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));
export const mix = (a, b, t) => a + (b - a) * t;
export const easeInOut = (t) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);
const easeOut = (t) => 1 - (1 - t) ** 3;
export const progress = (t, start, length, ease = easeInOut) => ease(clamp((t - start) / length));

export const motion = { scale: 1 };

export const el = (tag, className, parent, text) => {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  parent?.append(node);
  return node;
};

export const place = (node, { x = 0, y = 0, scale = 1, opacity = 1 }) => {
  node.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
  node.style.opacity = String(opacity);
};

export const rise = (node, t, start, { length = 0.7, distance = 24, x = 0, y = 0, scale = 1 } = {}) => {
  const p = progress(t, start, length, easeOut);
  place(node, { x, y: y + (1 - p) * distance * motion.scale, scale, opacity: p });
  return p;
};

export const fill = (template, values) => template.replace(/\{(\w+)\}/g, (_, key) => values[key] ?? '');

