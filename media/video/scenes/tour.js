import { device } from './devices.js';
import { footage } from './footage.js';
import { clamp, el, easeInOut, mix, motion, place, progress } from './kit.js';

const lead = 0.4;
const blend = 0.35;

export default async (layer, beat, data) => {
  const spec = data.devices[beat.device];
  const phones = [0, 1].map(() => device(layer, spec));
  const clips = phones.map((phone) => footage(data, beat.clip, phone.img));
  const marks = data.marks.tour;
  let start = lead;
  const segments = beat.segments.map((segment) => {
    const placed = { ...segment, start, clip: marks[segment.from] - segment.lead };
    start += segment.length;
    return placed;
  });
  segments.forEach((segment, index) => {
    const previous = segments[index - 1];
    segment.cut = !previous || Math.abs(previous.clip + previous.length * previous.rate - segment.clip) > 0.1;
  });

  const title = el('h1', 'headline abs', layer, beat.title);
  title.style.width = '640px';
  title.style.fontSize = '56px';
  const items = segments.map((segment) => {
    const row = el('div', 'tour-item abs', layer);
    el('i', null, row);
    el('span', null, row, segment.label);
    return row;
  });

  const base = 960 / phones[0].height;
  const frame = (t, segment) => clamp(segment.clip + (t - segment.start) * segment.rate, 0, 1e4);

  return {
    update(t) {
      const index = Math.max(0, segments.findLastIndex((segment) => t >= segment.start));
      const current = segments[index];
      const previous = segments[index - 1];
      const blendCamera = previous ? easeInOut(clamp((t - current.start + 0.3) / 0.7)) : 1;
      const zoom = mix(previous?.zoom ?? current.zoom, current.zoom, blendCamera);
      const focus = mix(previous?.focus ?? current.focus, current.focus, blendCamera);
      const camera = motion.scale * progress(t, 0, 0.8);
      const scale = base * mix(1, zoom, camera);
      const x = 1290 - (phones[0].width / 2) * scale;
      const y = 540 - mix(phones[0].height / 2, 14 + focus * spec.screen[1], camera) * scale;
      const fade = current.cut && previous ? progress(t, current.start, blend) : 1;
      const front = index % 2;
      place(phones[front].root, { x, y, scale, opacity: 1 });
      place(phones[1 - front].root, { x, y, scale, opacity: fade < 1 ? 1 : 0 });
      phones[front].root.style.opacity = String(fade);
      phones[front].root.style.zIndex = '2';
      phones[1 - front].root.style.zIndex = '1';
      place(title, { x: 150, y: 318, opacity: progress(t, 0.1, 0.6) });
      items.forEach((row, rowIndex) => {
        const active = rowIndex === index && t >= segments[0].start - 0.2;
        row.classList.toggle('tour-item--on', active);
        place(row, { x: 150, y: 470 + rowIndex * 62, opacity: progress(t, 0.3 + rowIndex * 0.08, 0.5) });
      });
      const loads = [clips[front].at(frame(Math.max(t, current.start), current))];
      if (fade < 1 && previous) loads.push(clips[1 - front].at(frame(t, previous)));
      return Promise.all(loads);
    },
  };
};
