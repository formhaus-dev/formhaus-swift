import '@fontsource-variable/inter';
import '@formhaus/core/style.css';
import './page.css';
import { createElement as h, useEffect } from 'react';
import { createRoot } from 'react-dom/client';
import { FormRenderer } from '@formhaus/react';

const params = new URLSearchParams(location.search);
const name = params.get('def') ?? 'base';
document.documentElement.style.zoom = params.get('zoom') ?? '1';
const definition = await (await fetch(`../../footage/definitions/${name}.json`)).json();

function Page() {
  useEffect(() => {
    document.documentElement.dataset.ready = 'true';
  }, []);
  return h(
    'div',
    { className: 'page' },
    h('h1', null, definition.title),
    h(FormRenderer, { definition, onSubmit: async () => {} }),
  );
}

createRoot(document.getElementById('root')).render(h(Page));
