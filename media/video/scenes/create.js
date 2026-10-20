import { device } from './devices.js';
import { footage } from './footage.js';
import { jsonCard } from './jsoncard.js';
import { el, fill, place, progress } from './kit.js';

const split = (layer) => {
  const node = el('div', 'abs', layer);
  node.style.width = '1920px';
  node.style.height = '1080px';
  return node;
};

export default async (layer, beat, data) => {
  const ai = split(layer);
  const panel = el('div', 'assistant abs', ai);
  el('div', 'assistant__bar', panel, beat.assistant.title);
  const prompt = el('div', 'assistant__prompt', panel);
  const tool = el('div', 'assistant__tool', panel, beat.assistant.tool);
  const result = el('div', 'assistant__result', panel, `${data.mcp.output}\n${fill(beat.assistant.result, { issues: data.mcp.issues })}`);
  const { card, lines } = jsonCard(ai, data, 16);
  card.style.width = '860px';

  const editor = split(layer);
  const spec = data.devices[beat.builder.device];
  const frame = device(editor, spec);
  const clip = footage(data, beat.builder.clip, frame.img);
  const scale = 790 / frame.height;
  const caption = el('div', 'caption abs', layer, beat.caption);
  const text = beat.assistant.prompt;

  return {
    update(t) {
      const swap = progress(t, beat.cut - 0.15, 0.3);
      ai.style.opacity = String(1 - swap);
      editor.style.opacity = String(swap);
      place(panel, { x: 120, y: 150, opacity: progress(t, 0, 0.4) });
      prompt.textContent = text.slice(0, Math.round(progress(t, 0.15, 0.8, (p) => p) * text.length));
      tool.style.opacity = String(progress(t, 1.05, 0.25));
      result.style.opacity = String(progress(t, 1.35, 0.25));
      place(card, { x: 940, y: 110, opacity: progress(t, 1.3, 0.3) });
      lines.forEach((line, index) => {
        line.style.opacity = String(progress(t, 1.4 + index * 0.05, 0.2));
      });
      place(frame.root, { x: (1920 - frame.width * scale) / 2, y: 50, scale });
      place(caption, { y: 920 + (1 - progress(t, 0.3, 0.6)) * 12, opacity: progress(t, 0.3, 0.6) });
      return clip.at(Math.max(0, t - beat.cut) + 0.9);
    },
  };
};
