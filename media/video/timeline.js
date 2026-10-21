import { el, motion, progress } from './scenes/kit.js';

const params = new URLSearchParams(location.search);
const capture = params.has('capture') || params.has('frame');
const data = await (await fetch('build/data.json', { cache: 'no-store' })).json();
const root = document.documentElement;
const stage = document.getElementById('stage');

for (const [name, value] of Object.entries(data.theme.colors)) root.style.setProperty(`--c-${name}`, value);
root.style.setProperty('--font-sans', data.theme.fonts.sans);
root.style.setProperty('--font-mono', data.theme.fonts.mono);

const reduced = params.has('calm') || (!capture && matchMedia('(prefers-reduced-motion: reduce)').matches);
motion.scale = reduced ? 0 : 1;

const { fps, transition } = data.output;
const scenes = await Promise.all(
  data.beats.map(async (beat, index) => {
    const layer = el('div', 'layer', stage);
    layer.style.zIndex = String(index);
    const module = await import(`./scenes/${beat.scene}.js`);
    const scene = await module.default(layer, beat, data);
    return { beat, layer, scene, index };
  }),
);

const cut = params.has('calm');
const last = data.beats.length - 1;
const pushes = (index) => !cut && index > 0 && data.beats[index].scene !== data.beats[index - 1].scene;
const visible = ({ beat, index }, t) =>
  t >= beat.start && (t < beat.start + beat.duration + (index < last && pushes(index + 1) ? transition : 0) || index === last);

const offset = ({ beat, index }, t) => {
  const entering = pushes(index) ? 1 - progress(t - beat.start, 0, transition) : 0;
  const leaving = index < last && pushes(index + 1) ? progress(t - beat.start - beat.duration, 0, transition) : 0;
  return (entering - leaving) * 1920;
};

export const renderFrame = async (frame) => {
  const t = frame / fps;
  const pending = [];
  for (const entry of scenes) {
    const show = visible(entry, t);
    entry.layer.style.display = show ? 'block' : 'none';
    if (!show) continue;
    const local = t - entry.beat.start;
    entry.layer.style.transform = `translateX(${offset(entry, t)}px)`;
    pending.push(entry.scene.update(local));
  }
  await Promise.all(pending);
  await document.fonts.ready;
};

const fit = () => {
  const scale = Math.min(innerWidth / 1920, innerHeight / 1080);
  stage.style.transform = `translate(${(innerWidth - 1920 * scale) / 2}px, ${(innerHeight - 1080 * scale) / 2}px) scale(${scale})`;
};

window.renderFrame = renderFrame;
window.totalFrames = data.frames;

if (capture) {
  await renderFrame(Number(params.get('frame') ?? 0));
  root.dataset.ready = 'true';
} else {
  fit();
  addEventListener('resize', fit);
  const begin = performance.now();
  let busy = false;
  const tick = async () => {
    requestAnimationFrame(tick);
    if (busy) return;
    busy = true;
    await renderFrame(Math.floor(((performance.now() - begin) / 1000) * fps) % data.frames);
    busy = false;
  };
  tick();
}
