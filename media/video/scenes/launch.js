import { device } from './devices.js';
import { footage } from './footage.js';
import { easeOut, el, mix, motion, place, progress } from './kit.js';

const settle = (t, start) => {
  const p = progress(t, start, 1.4, easeOut);
  return { lift: (1 - p) * 60 * motion.scale, grow: mix(1.04, 1, motion.scale ? p : 1), opacity: progress(t, start, 0.6) };
};

export default async (layer, beat, data) => {
  const mac = device(layer, data.devices[beat.devices.mac]);
  const phone = device(layer, data.devices[beat.devices.phone]);
  const clips = [footage(data, beat.stills.mac, mac.img), footage(data, beat.stills.phone, phone.img)];
  const title = el('h1', 'headline headline--center launch-title abs', layer, beat.title);
  const subline = el('p', 'sub launch-sub abs', layer, beat.subline);
  subline.style.width = '1920px';
  subline.style.textAlign = 'center';
  const macBase = 560 / mac.height;
  const phoneBase = 640 / phone.height;
  const gap = 70;
  const left = (1920 - mac.width * macBase - gap - phone.width * phoneBase) / 2;

  return {
    update(t) {
      const back = settle(t, 0);
      const front = settle(t, 0.15);
      const macScale = macBase * back.grow;
      const phoneScale = phoneBase * front.grow;
      place(mac.root, { x: left, y: 380 + back.lift, scale: macScale, opacity: back.opacity });
      place(phone.root, { x: left + mac.width * macBase + gap, y: 300 + front.lift, scale: phoneScale, opacity: front.opacity });
      place(title, { y: 96 + (1 - progress(t, 0, 0.8, easeOut)) * 20, opacity: progress(t, 0, 0.6) });
      place(subline, { y: 208, opacity: progress(t, 0.4, 0.6) });
      return Promise.all(clips.map((clip) => clip.at(beat.at)));
    },
  };
};
