// Render the existing Android vector brand into the iOS asset catalogue.
// Uses a local browser; no external image services or network requests.
const {chromium} = require(process.env.LIULIANG_PLAYWRIGHT_MODULE ||
  '../.tools/browser/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const color = value => value === '#00000000' ? 'none' : value;

(async () => {
  const vector = await fs.readFile(path.join(root,
    'app/android/app/src/main/res/drawable/app_icon.xml'), 'utf8');
  const paths = [...vector.matchAll(/<path\s+([^>]+)\/>/g)].map(match => {
    const attributes = Object.fromEntries([...match[1].matchAll(/android:(\w+)="([^"]*)"/g)]
      .map(item => [item[1], item[2]]));
    return `<path d="${attributes.pathData}" fill="${color(attributes.fillColor || 'none')}"` +
      (attributes.strokeColor ? ` stroke="${color(attributes.strokeColor)}"` : '') +
      (attributes.strokeWidth ? ` stroke-width="${attributes.strokeWidth}"` : '') +
      (attributes.strokeLineCap ? ` stroke-linecap="${attributes.strokeLineCap}"` : '') + '/>';
  }).join('');
  const catalogue = path.join(root, 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const contents = JSON.parse(await fs.readFile(path.join(catalogue, 'Contents.json'), 'utf8'));
  const browser = await chromium.launch({headless: true,
    ...(process.env.LIULIANG_CHROME_PATH ?
      {executablePath: process.env.LIULIANG_CHROME_PATH} : {channel: 'chrome'})});
  try {
    const page = await browser.newPage({deviceScaleFactor: 1});
    await page.route('**/*', route => route.abort());
    const rendered = new Set();
    for (const asset of contents.images) {
      if (!asset.filename || rendered.has(asset.filename)) continue;
      rendered.add(asset.filename);
      const pixels = Number(asset.size.split('x')[0]) * Number(asset.scale.replace('x', ''));
      await page.setViewportSize({width: pixels, height: pixels});
      await page.setContent(`<style>html,body{margin:0;background:#FFF4E6}svg{display:block}</style>` +
        `<svg xmlns="http://www.w3.org/2000/svg" width="${pixels}" height="${pixels}" viewBox="0 0 96 96">` +
        `<rect width="96" height="96" fill="#FFF4E6"/>${paths}</svg>`);
      await page.screenshot({path: path.join(catalogue, asset.filename), omitBackground: false});
    }
    process.stdout.write(`Rendered ${rendered.size} opaque iOS brand icons.\n`);
  } finally {
    await browser.close();
  }
})().catch(error => {process.stderr.write(`${error.stack}\n`); process.exitCode = 1;});
