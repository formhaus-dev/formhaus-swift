import { device } from './devices.js';
import { footage } from './footage.js';
import { el, place, progress } from './kit.js';

export const pair = (layer, data, beat, height, top) => {
  const web = device(layer, data.devices[beat.devices.web]);
  const ios = device(layer, data.devices[beat.devices.ios]);
  const webScale = height / web.height;
  const iosScale = height / ios.height;
  const gap = 120;
  const width = web.width * webScale + gap + ios.width * iosScale;
  const left = (1920 - width) / 2;
  const slots = {
    web: { node: web, x: left, scale: webScale, width: web.width * webScale },
    ios: { node: ios, x: left + web.width * webScale + gap, scale: iosScale, width: ios.width * iosScale },
  };
  const show = (t, start) => {
    for (const [index, slot] of Object.values(slots).entries()) {
      const p = progress(t, start + index * 0.12, 0.8);
      place(slot.node.root, { x: slot.x, y: top + (1 - p) * 26, scale: slot.scale, opacity: p });
    }
  };
  return { slots, show };
};

export default async (layer, beat, data) => {
  const { slots, show } = pair(layer, data, beat, 825, 112);
  const marks = data.marks.tour;
  const clips = { web: footage(data, beat.clips.web, slots.web.node.img), ios: footage(data, beat.clips.ios, slots.ios.node.img) };
  const labels = Object.entries(slots).map(([key, slot]) => {
    const label = el('div', 'label abs', layer, beat.labels[key]);
    label.style.width = `${slot.width}px`;
    label.style.textAlign = 'center';
    return { label, slot };
  });
  const steps = beat.steps.map((step) => ({ at: marks[step.at] - beat.from, node: el('div', 'caption caption--muted abs', layer, step.text) }));
  const caption = el('div', 'caption abs', layer, beat.caption.text);
  const captionAt = marks[beat.caption.at] + beat.caption.lead - beat.from;
  const until = marks.back - 0.05;

  return {
    update(t) {
      show(t, 0);
      for (const { label, slot } of labels) {
        label.style.opacity = String(progress(t, 0.3, 0.6));
        label.style.transform = `translate(${slot.x}px, 62px)`;
      }
      const final = progress(t, captionAt, 0.6);
      steps.forEach((step, index) => {
        const next = steps[index + 1]?.at ?? captionAt;
        const enter = progress(t, step.at + 0.05, 0.3);
        const leave = progress(t, next - 0.3, 0.25);
        place(step.node, { y: 966 + (1 - enter) * 12, opacity: enter * (1 - leave) });
      });
      caption.style.opacity = String(final);
      caption.style.transform = `translateY(${960 + (1 - final) * 14}px)`;
      const clipTime = Math.min(beat.from + t, until);
      return Promise.all([clips.web.at(clipTime), clips.ios.at(clipTime)]);
    },
  };
};
