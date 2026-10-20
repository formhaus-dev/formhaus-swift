import '@formhaus/editor-react/mount.css';
import { createMemoryHost, mount } from '@formhaus/editor-react/mount';

const params = new URLSearchParams(location.search);
document.documentElement.style.zoom = params.get('zoom') ?? '1';
const definition = await (await fetch('/footage/definitions/base.json')).json();
mount(document.getElementById('editor'), { host: createMemoryHost({ definition }) });
document.documentElement.dataset.ready = 'true';
