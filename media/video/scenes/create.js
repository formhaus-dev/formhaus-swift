import { codePanels } from './codepanels.js';
import { device } from './devices.js';
import { footage } from './footage.js';
import { jsonCard } from './jsoncard.js';
import { easeInOut, el, fill, mix, place, progress } from './kit.js';
import { driftShown } from './problem.js';

const cardWidth = 860;
const cardX = 940;
const cardY = 110;

const full = (layer) => {
  const node = el('div', 'abs', layer);
  node.style.width = '1920px';
  node.style.height = '1080px';
  return node;
};

const collapse = (panels, card, t) => {
  const merge = progress(t, 0, 0.8, easeInOut);
  const center = { x: 960 - cardWidth / 2, y: cardY };
  const middle = cardY + (card.offsetHeight || 640) / 2;
  for (const panel of panels) {
    const scale = mix(1, cardWidth / panel.width, merge);
    const y = mix(panel.y, middle - (panel.height * scale) / 2, merge);
    place(panel.card, { x: mix(panel.x, center.x, merge), y, scale, opacity: 1 - progress(t, 0.35, 0.35) });
    driftShown(panel, 10);
  }
  const slide = progress(t, 0.9, 0.7, easeInOut);
  place(card, { x: mix(center.x, cardX, slide), y: cardY, opacity: progress(t, 0.4, 0.4) });
};

export default async (layer, beat, data) => {
  const ai = full(layer);
  const panels = codePanels(ai, data.beats.find((item) => item.scene === 'problem'));
  const panel = el('div', 'assistant abs', ai);
  el('div', 'assistant__bar', panel, beat.assistant.title);
  const prompt = el('div', 'assistant__prompt', panel);
  const tool = el('div', 'assistant__tool', panel, beat.assistant.tool);
  const result = el('div', 'assistant__result', panel, `${data.mcp.output}\n${fill(beat.assistant.result, { issues: data.mcp.issues })}`);
  const { card } = jsonCard(ai, data, 16);
  card.style.width = `${cardWidth}px`;

  const editor = full(layer);
  const frame = device(editor, data.devices[beat.builder.device]);
  const clip = footage(data, beat.builder.clip, frame.img);
  const scale = 790 / frame.height;
  const caption = el('div', 'caption abs', layer, beat.caption);
  const text = beat.assistant.prompt;

  return {
    update(t) {
      const swap = progress(t, beat.cut - 0.15, 0.3);
      ai.style.opacity = String(1 - swap);
      editor.style.opacity = String(swap);
      collapse(panels, card, t);
      place(panel, { x: 120, y: 150, opacity: progress(t, 1.1, 0.4) });
      prompt.textContent = text.slice(0, Math.round(progress(t, 1.2, 0.8, (p) => p) * text.length));
      tool.style.opacity = String(progress(t, 2.1, 0.25));
      result.style.opacity = String(progress(t, 2.35, 0.25));
      place(frame.root, { x: (1920 - frame.width * scale) / 2, y: 50, scale });
      place(caption, { y: 920 + (1 - progress(t, 0.7, 0.6)) * 12, opacity: progress(t, 0.7, 0.6) });
      return clip.at(Math.max(0, t - beat.cut) + 0.9);
    },
  };
};
