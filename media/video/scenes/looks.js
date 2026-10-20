import { device } from './devices.js';
import { footage } from './footage.js';
import { captionHeight, el, place, progress, stack } from './kit.js';

const height = 660;
const pill = 58;
const hold = 1.3;
const blend = 0.25;

export default async (layer, beat, data) => {
  const title = el('div', 'caption abs', layer, beat.title);
  const phone = device(layer, data.devices.iphone);
  const looks = beat.sets.map((set, index) => {
    const img = index === 0 ? phone.img : el('img', 'look-layer', phone.screen);
    img.alt = '';
    const label = el('div', 'pill pill--large abs', layer, set.name);
    return { img, label, clip: footage(data, beat.clip, img, { touches: false }), time: data.marks.styles[set.at] + set.offset };
  });

  return {
    update(t) {
      const [captionY, top, labelY] = stack([[captionHeight, 48], [height, 18], [pill]]);
      place(title, { y: captionY, opacity: progress(t, 0, 0.5) });
          const scale = height / phone.height;
      place(phone.root, { x: (1920 - phone.width * scale) / 2, y: top, scale });
      looks.forEach((look, index) => {
        const enter = index === 0 ? 1 : progress(t, 0.4 + index * hold, blend);
        const leave = looks[index + 1] ? progress(t, 0.4 + (index + 1) * hold, blend) : 0;
        look.img.style.opacity = String(enter);
        const shown = enter * (1 - leave);
        place(look.label, { x: (1920 - look.label.offsetWidth) / 2, y: labelY, opacity: shown });
      });
      return Promise.all(looks.map((look) => look.clip.at(look.time)));
    },
  };
};
