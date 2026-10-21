import { device } from './devices.js';
import { footage } from './footage.js';
import { captionHeight, clamp, el, place, progress, softIn, stack } from './kit.js';

const lead = 0.2;
const blend = 0.2;
const height = 660;

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

  const title = el('div', 'caption abs', layer, beat.title);
  const items = segments.map((segment) => {
    const row = el('div', 'tour-item abs', layer);
    el('i', null, row);
    el('span', null, row, segment.label);
    return row;
  });
  const base = height / phones[0].height;
  const [captionY, top] = stack([[captionHeight, 48], [height]]);
  const clipTime = (t, segment) => segment.clip + clamp(t - segment.start, 0, segment.length) * segment.rate;

  return {
    update(t) {
      const index = Math.max(0, segments.findLastIndex((segment) => t >= segment.start));
      const current = segments[index];
      const previous = segments[index - 1];
      const scale = base;
      const x = 1180 - (phones[0].width * scale) / 2;
      const y = top + (height - phones[0].height * scale) / 2;
      const fade = current.cut ? progress(t, current.start, blend) : 1;
      const front = index % 2;
      place(phones[front].root, { x, y, scale, opacity: fade });
      place(phones[1 - front].root, { x, y, scale, opacity: fade < 1 ? 1 - fade : 0 });
      place(title, { y: captionY });
      softIn(title, t, 0.15);
      items.forEach((row, rowIndex) => {
        row.classList.toggle('tour-item--on', rowIndex === index);
        place(row, { x: 150, y: top + height / 2 - (items.length * 80) / 2 + rowIndex * 80 });
      });
      const loads = [clips[front].at(clipTime(t, current), current.rate)];
      if (fade < 1 && previous) loads.push(clips[1 - front].at(clipTime(t, previous), previous.rate));
      return Promise.all(loads);
    },
  };
};
