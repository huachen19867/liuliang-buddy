// Package the project artwork at its actual display resolutions. No network.
const { chromium } = require(process.env.LIULIANG_PLAYWRIGHT_MODULE ||
  '../.tools/browser/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const root = path.resolve(__dirname, '..');

(async () => {
  const icon = await fs.readFile(path.join(root, 'app/assets/resort/app-icon.png'));
  const widget = await fs.readFile(path.join(root, 'app/assets/resort/widget-mascot.png'));
  const browser = await chromium.launch({ headless: true,
    ...(process.env.LIULIANG_CHROME_PATH ?
      { executablePath: process.env.LIULIANG_CHROME_PATH } : { channel: 'chrome' }) });
  try {
    const page = await browser.newPage();
    await page.route('**/*', route => route.abort());
    async function resize(input, width, height, destination, opaque) {
      const result = await page.evaluate(async ({ data, width, height, opaque }) => {
        const image = new Image();
        image.src = `data:image/png;base64,${data}`;
        await image.decode();
        const canvas = document.createElement('canvas');
        canvas.width = width; canvas.height = height;
        const ctx = canvas.getContext('2d');
        if (opaque) { ctx.fillStyle = '#FFFBF5'; ctx.fillRect(0, 0, width, height); }
        ctx.imageSmoothingQuality = 'high';
        const scale = Math.min(width / image.width, height / image.height);
        const w = image.width * scale, h = image.height * scale;
        ctx.drawImage(image, (width - w) / 2, (height - h) / 2, w, h);
        return canvas.toDataURL('image/png').split(',')[1];
      }, { data: input.toString('base64'), width, height, opaque });
      await fs.mkdir(path.dirname(destination), { recursive: true });
      await fs.writeFile(destination, Buffer.from(result, 'base64'));
    }
    const res = path.join(root, 'app/android/app/src/main/res');
    for (const [density, pixels] of Object.entries({ mdpi: 48, hdpi: 72,
      xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
      await resize(icon, pixels, pixels, path.join(res, `mipmap-${density}/ic_launcher.png`), true);
    }
    await resize(icon, 432, 432, path.join(res, 'drawable-nodpi/app_icon_resort.png'), true);
    await resize(widget, 156, 104, path.join(res, 'drawable-nodpi/widget_mascot.png'), false);
    const catalogue = path.join(root, 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset');
    const contents = JSON.parse(await fs.readFile(path.join(catalogue, 'Contents.json'), 'utf8'));
    const seen = new Set();
    for (const asset of contents.images) {
      if (!asset.filename || seen.has(asset.filename)) continue;
      seen.add(asset.filename);
      const pixels = Number(asset.size.split('x')[0]) * Number(asset.scale.replace('x', ''));
      await resize(icon, pixels, pixels, path.join(catalogue, asset.filename), true);
    }
    console.log(`Packaged 5 Android launcher sizes, adaptive artwork, widget ornament and ${seen.size} opaque iOS icons.`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
