import { device } from './devices.js';
import { footage } from './footage.js';
import { clamp, el, easeInOut, mix, motion, place, progress } from './kit.js';

const lead = 0.4;
const blend = 0.35;
const move = 0.9;

const camera = (segments, t, key) =>
  segments.slice(1).reduce((value, segment, index) => {
    const weight = easeInOut(clamp((t - segment.start + move / 2) / move));
    return value + weight * (segment[key] - segments[index][key]);
  }, segments[0][key]);

export default async (layer, beat, data) => {
  const spec = data.devices[beat.device];
  const phones = [0, 1].map(() => device(layer, spec));
  const clips = phones.map((phone) => footage(data, beat.clip, phone.img));
  const marks = data.marks[beat.script];
  let start = lead;
  const segments = beat.segments.map((segment) => {
    const placed = { ...segment, start, clip: marks[segment.from] - segment.lead };
    start += segment.length;
    return placed;
  });
  segments.forEach((segment, index) => {
    const previous = segments[index - 1];
    segment.cut = Boolean(previous) && Math.abs(previous.clip + previous.length * previous.rate - segment.clip) > 0.1;
  });

  const title = el('h1', 'headline abs', layer, beat.title);
  title.style.fontSize = '64px';
  title.style.width = '720px';
  title.style.whiteSpace = 'normal';
  const items = segments.map((segment) => {
    const row = el('div', 'tour-item abs', layer);
    el('i', null, row);
    el('span', null, row, segment.label);
    return row;
  });

  const base = 1000 / phones[0].height;
  const clipTime = (t, segment) => segment.clip + clamp(t - segment.start, 0, segment.length) * segment.rate;

  return {
    update(t) {
      const index = Math.max(0, segments.findLastIndex((segment) => t >= segment.start));
      const current = segments[index];
      const previous = segments[index - 1];
      const zoomed = motion.scale * progress(t, 0, 0.8);
      const scale = base * mix(1, camera(segments, t, 'zoom'), zoomed);
      const focus = 14 + camera(segments, t, 'focus') * spec.screen[1];
      const x = 1340 - (phones[0].width / 2) * scale;
      const y = 540 - mix(phones[0].height / 2, focus, zoomed) * scale;
      const fade = current.cut ? progress(t, current.start, blend) : 1;
      const front = index % 2;
      place(phones[front].root, { x, y, scale, opacity: fade });
      place(phones[1 - front].root, { x, y, scale, opacity: fade < 1 ? 1 : 0 });
      phones[front].root.style.zIndex = '2';
      phones[1 - front].root.style.zIndex = '1';
      place(title, { x: 130, y: 210, opacity: progress(t, 0.1, 0.6) });
      items.forEach((row, rowIndex) => {
        row.classList.toggle('tour-item--on', rowIndex === index);
        place(row, { x: 130, y: 480 + rowIndex * 74, opacity: progress(t, 0.3 + rowIndex * 0.08, 0.5) });
      });
      const loads = [clips[front].at(clipTime(t, current), current.rate)];
      if (fade < 1 && previous) loads.push(clips[1 - front].at(clipTime(t, previous), previous.rate));
      return Promise.all(loads);
    },
  };
};
