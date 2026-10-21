import { device } from './devices.js';
import { footage } from './footage.js';
import { captionHeight, el, place, playWords, stack, words } from './kit.js';

const height = 660;
const pill = 58;
const lead = 0.3;
const hold = 1.1;

const shownAt = (t, index) => index === 0 || t >= lead + index * hold;

export default async (layer, beat, data) => {
  const title = el('div', 'caption abs', layer);
  const titleWords = words(title, beat.title);
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
      playWords(titleWords, t, 0.15);
      place(title, { y: captionY });
      const scale = height / phone.height;
      place(phone.root, { x: (1920 - phone.width * scale) / 2, y: top, scale });
      looks.forEach((look, index) => {
        const shown = shownAt(t, index) && !(looks[index + 1] && shownAt(t, index + 1));
        look.img.style.opacity = shownAt(t, index) ? '1' : '0';
        place(look.label, { x: (1920 - look.label.offsetWidth) / 2, y: labelY, opacity: shown ? 1 : 0 });
      });
      return Promise.all(looks.map((look) => look.clip.at(look.time)));
    },
  };
};
