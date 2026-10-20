import { chromium } from 'playwright';
import { serve } from './serve.mjs';

export const withComposition = async (data, scale, query, use) => {
  const { width, height } = data.output;
  const server = await serve();
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: scale, reducedMotion: 'no-preference' });
    page.on('pageerror', (error) => console.error(error.message));
    await page.goto(`${server.origin}/index.html?${query}`);
    await page.waitForSelector('html[data-ready="true"]', { state: 'attached', timeout: 120000 });
    return await use(page);
  } finally {
    await browser.close();
    await server.close();
  }
};
