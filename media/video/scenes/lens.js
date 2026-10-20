import { footage } from './footage.js';
import { el } from './kit.js';

const pad = 24;

export const lens = (parent, data, { device, clips, rect, scale, box, fade = false }) => {
  const spec = data.devices[device];
  const [screenWidth, screenHeight] = spec.viewport ?? spec.screen;
  const [x, y, w, h] = rect;
  const zoom = box ? Math.min((box[0] - pad * 2) / (w * screenWidth), box[1] / (h * screenHeight)) : scale;
  const width = box ? box[0] : w * screenWidth * zoom;
  const height = box ? box[1] : h * screenHeight * zoom;
  const left = (box ? pad : 0) - x * screenWidth * zoom;
  const top = (height - h * screenHeight * zoom) / 2 - y * screenHeight * zoom;
  const card = el('div', `lens abs${fade ? ` lens--fade${fade === 'both' ? '-both' : ''}` : ''}`, parent);
  Object.assign(card.style, { width: `${width}px`, height: `${height}px` });
  const players = clips.map((clip) => {
    const img = el('img', null, card);
    img.alt = '';
    Object.assign(img.style, {
      width: `${screenWidth * zoom}px`,
      height: `${screenHeight * zoom}px`,
      left: `${left}px`,
      top: `${top}px`,
    });
    return { img, player: footage(data, clip, img, { touches: false }) };
  });
  return { card, width, height, players };
};
