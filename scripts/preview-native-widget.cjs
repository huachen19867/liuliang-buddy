#!/usr/bin/env node

// Render the current Android RemoteViews layout in a browser without invoking the Android SDK.
// The page uses the real layout XML, real shape drawable XML and mascot bitmap from app/android.

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const resourceRoot = path.join(root, 'app/android/app/src/main/res');
const layoutPath = path.join(resourceRoot, 'layout/traffic_widget.xml');
const outputPath = path.join(root, 'artifacts/widget-glass-preview.png');

const demo = {
  widget_root: { visibility: 'visible' },
  widget_mascot: { visibility: 'visible' },
  widget_empty: { visibility: 'gone' },
  widget_more: { visibility: 'gone' },
  slot_1: { visibility: 'visible' },
  slot_1_badge: { text: '移' },
  slot_1_name: { text: '中国移动1' },
  slot_1_state: { visibility: 'gone' },
  slot_1_phone: { visibility: 'gone' },
  slot_1_balance: { visibility: 'gone' },
  slot_1_summary: { visibility: 'gone' },
  slot_1_time: { text: '10/01 22:15', visibility: 'visible' },
  slot_1_general: { text: '51.81 GB' },
  slot_1_directed: { text: '30.00 GB' },
  slot_1_other: { text: '137.42 GB' },
  slot_1_voice: { text: '0 分钟' },
  slot_2: { visibility: 'visible' },
  slot_2_badge: { text: '广' },
  slot_2_name: { text: '中国广电1' },
  slot_2_state: { visibility: 'gone' },
  slot_2_phone: { visibility: 'gone' },
  slot_2_balance: { visibility: 'gone' },
  slot_2_summary: { visibility: 'gone' },
  slot_2_time: { text: '10/01 22:15', visibility: 'visible' },
  slot_2_general: { text: '—' },
  slot_2_directed: { text: '—' },
  slot_2_other: { text: '328.44 GB' },
  slot_2_voice: { text: '—' },
  slot_3: { visibility: 'gone' },
  slot_4: { visibility: 'gone' },
};

function readRequired(file) {
  if (!fs.existsSync(file)) throw new Error(`Required input not found: ${path.relative(root, file)}`);
  return fs.readFileSync(file);
}

function drawableFiles(layoutXml) {
  const names = [...new Set([...layoutXml.matchAll(/@drawable\/([\w]+)/g)].map((m) => m[1]))];
  const files = {};
  for (const name of names) {
    const candidates = [
      path.join(resourceRoot, 'drawable', `${name}.xml`),
      path.join(resourceRoot, 'drawable', `${name}.png`),
      path.join(resourceRoot, 'drawable-nodpi', `${name}.xml`),
      path.join(resourceRoot, 'drawable-nodpi', `${name}.png`),
    ];
    const file = candidates.find((candidate) => fs.existsSync(candidate));
    if (!file) throw new Error(`Drawable @drawable/${name} was referenced but not found.`);
    const bytes = readRequired(file);
    const ext = path.extname(file).toLowerCase();
    files[name] = ext === '.png'
      ? { kind: 'image', dataUrl: `data:image/png;base64,${bytes.toString('base64')}` }
      : { kind: 'xml', xml: bytes.toString('utf8') };
  }
  return files;
}

function findChrome() {
  const candidates = [
    process.env.LIULIANG_CHROME_PATH,
    'C:/Program Files/Google/Chrome/Application/chrome.exe',
    'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  ].filter(Boolean);
  const executablePath = candidates.find((candidate) => fs.existsSync(candidate));
  if (!executablePath) throw new Error('Chrome was not found. Set LIULIANG_CHROME_PATH to a local chrome.exe.');
  return executablePath;
}

async function main() {
  const layoutXml = readRequired(layoutPath).toString('utf8');
  const assets = drawableFiles(layoutXml);
  const xmlB64 = Buffer.from(layoutXml).toString('base64');
  const assetsB64 = Buffer.from(JSON.stringify(assets)).toString('base64');
  const demoB64 = Buffer.from(JSON.stringify(demo)).toString('base64');
  const playwrightPath = path.join(root, '.tools/browser/node_modules/playwright');
  if (!fs.existsSync(playwrightPath)) throw new Error('Local Playwright module is missing at .tools/browser/node_modules/playwright.');
  const { chromium } = require(playwrightPath);
  const browser = await chromium.launch({ headless: true, executablePath: findChrome() });

  try {
    const page = await browser.newPage({ viewport: { width: 400, height: 480 }, deviceScaleFactor: 2 });
    const html = `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  * { box-sizing: border-box; }
  html, body { width: 400px; height: 480px; margin: 0; overflow: hidden; }
  body {
    position: relative;
    color: #273244;
    font-family: Roboto, Arial, "Microsoft YaHei UI", "Microsoft YaHei", sans-serif;
    background: linear-gradient(151deg, #dbe5ef 0%, #cedae7 35%, #dbe3eb 68%, #cbd7e3 100%);
  }
  .preview-label {
    position: absolute; left: 50%; top: 16px; transform: translateX(-50%);
    z-index: 10; padding: 7px 13px; border: 1px solid rgba(255,255,255,.68);
    border-radius: 999px; color: #39485d; background: rgba(248,250,252,.56);
    font-size: 11px; line-height: 15px; letter-spacing: .1px; white-space: nowrap;
  }
  #widget-stage { position: absolute; left: 8px; top: 62px; width: 384px; height: 280px; }
  .native-layout { display: flex; min-width: 0; min-height: 0; flex-shrink: 0; overflow: hidden; }
  .native-text {
    min-width: 0; min-height: 0; flex-shrink: 0; overflow: hidden;
    white-space: nowrap; text-overflow: ellipsis; line-height: 1.15;
  }
  .native-image { flex-shrink: 0; object-fit: contain; }
</style>
</head>
<body>
  <div class="preview-label">XML布局预览 · 合成数据 · 非手机实拍</div>
  <div id="widget-stage"></div>
  <script>
    (function () {
      try {
    function decodeBase64Utf8(value) {
      const binary = atob(value);
      const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
      return new TextDecoder().decode(bytes);
    }
    const layoutXml = decodeBase64Utf8('${xmlB64}');
    const assets = JSON.parse(decodeBase64Utf8('${assetsB64}'));
    const demo = JSON.parse(decodeBase64Utf8('${demoB64}'));
    const androidNS = 'http://schemas.android.com/apk/res/android';
    const documentXml = new DOMParser().parseFromString(layoutXml, 'application/xml');
    if (documentXml.querySelector('parsererror')) throw new Error('traffic_widget.xml is not valid XML.');

    function attr(node, key, fallback = '') {
      return node.getAttributeNS(androidNS, key) || node.getAttribute('android:' + key) || fallback;
    }
    function px(value) {
      if (!value || value === 'wrap_content' || value === 'match_parent') return value;
      if (value.endsWith('dp') || value.endsWith('sp')) return value.slice(0, -2) + 'px';
      return value;
    }
    function idName(raw) { return raw ? raw.split('/').pop() : ''; }
    function cssColor(androidColor) {
      if (!androidColor) return '';
      if (/^#[0-9a-f]{8}$/i.test(androidColor)) {
        const a = parseInt(androidColor.slice(1, 3), 16) / 255;
        const r = parseInt(androidColor.slice(3, 5), 16);
        const g = parseInt(androidColor.slice(5, 7), 16);
        const b = parseInt(androidColor.slice(7, 9), 16);
        return 'rgba(' + r + ',' + g + ',' + b + ',' + a.toFixed(4) + ')';
      }
      return androidColor;
    }
    function drawableStyle(reference, node) {
      if (!reference || !reference.startsWith('@drawable/')) return {};
      const name = reference.slice('@drawable/'.length);
      const resource = assets[name];
      if (!resource) throw new Error('Missing drawable payload for ' + reference);
      if (resource.kind === 'image') {
        node.classList.add('native-image');
        node.src = resource.dataUrl;
        node.alt = attr(node.__source, 'contentDescription', '');
        return {};
      }
      const parsed = new DOMParser().parseFromString(resource.xml, 'application/xml');
      if (parsed.querySelector('parsererror')) throw new Error('Invalid shape drawable XML: ' + name);
      const shape = parsed.documentElement;
      const style = {};
      const corners = shape.querySelector('corners');
      if (corners) style.borderRadius = px(attr(corners, 'radius', '0dp'));
      const solid = shape.querySelector('solid');
      if (solid) style.backgroundColor = cssColor(attr(solid, 'color'));
      const stroke = shape.querySelector('stroke');
      if (stroke) {
        style.border = px(attr(stroke, 'width', '1dp')) + ' solid ' + cssColor(attr(stroke, 'color', '#000000'));
      }
      const gradient = shape.querySelector('gradient');
      if (gradient) {
        const angle = Number(attr(gradient, 'angle', '0'));
        const start = cssColor(attr(gradient, 'startColor'));
        const end = cssColor(attr(gradient, 'endColor'));
        style.backgroundImage = 'linear-gradient(' + ((angle + 90) % 360) + 'deg, ' + start + ', ' + end + ')';
      }
      if (attr(shape, 'shape') === 'oval') style.borderRadius = '50%';
      return style;
    }
    function applyDimension(style, property, value) {
      if (value === 'match_parent') style[property] = '100%';
      else if (value === 'wrap_content') style[property] = 'max-content';
      else if (value) style[property] = px(value);
    }
    function childrenOf(node) { return [...node.children].filter((child) => child.nodeType === 1); }
    function render(source) {
      const type = source.localName;
      const nativeId = idName(attr(source, 'id'));
      const override = demo[nativeId] || {};
      const tag = type === 'ImageView' ? 'img' : 'div';
      const element = document.createElement(tag);
      element.__source = source;
      element.dataset.nativeType = type;
      if (nativeId) { element.id = nativeId; element.dataset.xmlId = nativeId; }

      const width = attr(source, 'layout_width', 'wrap_content');
      const height = attr(source, 'layout_height', 'wrap_content');
      const weight = Number(attr(source, 'layout_weight', '0')) || 0;
      const orientation = attr(source, 'orientation', 'horizontal');
      if (type === 'LinearLayout') {
        element.classList.add('native-layout');
        element.style.flexDirection = orientation === 'vertical' ? 'column' : 'row';
        if (orientation === 'horizontal') applyDimension(element.style, 'width', width === '0dp' && weight ? '0px' : width);
        else applyDimension(element.style, 'height', height === '0dp' && weight ? '0px' : height);
      } else if (type === 'TextView') {
        element.className = 'native-text';
        const text = override.text !== undefined ? override.text : attr(source, 'text', '');
        element.textContent = text;
        const textSize = attr(source, 'textSize');
        const textColor = attr(source, 'textColor');
        const maxLines = Number(attr(source, 'maxLines', '0'));
        const gravity = attr(source, 'gravity', '');
        if (textSize) element.style.fontSize = px(textSize);
        if (textColor) element.style.color = cssColor(textColor);
        if (attr(source, 'textStyle').includes('bold')) element.style.fontWeight = '700';
        if (maxLines > 0) {
          element.style.display = '-webkit-box';
          element.style.webkitBoxOrient = 'vertical';
          element.style.webkitLineClamp = String(maxLines);
          element.style.whiteSpace = 'normal';
        }
        if (gravity.includes('center')) element.style.textAlign = 'center';
        if (gravity.includes('right')) element.style.textAlign = 'right';
        if (gravity === 'center') {
          element.style.display = 'flex';
          element.style.alignItems = 'center';
          element.style.justifyContent = 'center';
        } else if (gravity.includes('center_vertical')) {
          element.style.display = 'flex';
          element.style.alignItems = 'center';
        }
      }

      element.style.boxSizing = 'border-box';
      element.style.minWidth = '0';
      element.style.minHeight = '0';
      element.style.flexShrink = '0';
      applyDimension(element.style, 'width', width);
      applyDimension(element.style, 'height', height);
      if (weight > 0) {
        const mainSize = orientation === 'vertical' ? height : width;
        if (mainSize === '0dp') {
          element.style.flexGrow = String(weight);
          element.style.flexBasis = '0px';
        } else {
          element.style.flexGrow = String(weight);
        }
      }

      const padding = attr(source, 'padding');
      if (padding) element.style.padding = px(padding);
      for (const [androidName, cssName] of [['paddingStart', 'paddingInlineStart'], ['paddingEnd', 'paddingInlineEnd'], ['paddingTop', 'paddingTop'], ['paddingBottom', 'paddingBottom']]) {
        const value = attr(source, androidName);
        if (value) element.style[cssName] = px(value);
      }
      const marginBottom = attr(source, 'layout_marginBottom');
      if (marginBottom) element.style.marginBottom = px(marginBottom);

      const background = attr(source, 'background');
      if (background) Object.assign(element.style, drawableStyle(background, element));
      if (type === 'ImageView') {
        const src = attr(source, 'src');
        if (src) Object.assign(element.style, drawableStyle(src, element));
        const scaleType = attr(source, 'scaleType');
        if (scaleType === 'fitCenter') element.style.objectFit = 'contain';
      }

      const gravity = attr(source, 'gravity', '');
      if (type === 'LinearLayout') {
        if (gravity.includes('center_vertical')) element.style.alignItems = orientation === 'horizontal' ? 'center' : '';
        if (gravity.includes('center_horizontal')) element.style.justifyContent = orientation === 'vertical' ? 'center' : '';
        if (gravity === 'center') { element.style.alignItems = 'center'; element.style.justifyContent = 'center'; }
      }

      const visibility = override.visibility || attr(source, 'visibility', 'visible');
      if (visibility === 'gone') element.style.display = 'none';
      for (const child of childrenOf(source)) element.appendChild(render(child));
      return element;
    }

    const allIds = [...documentXml.getElementsByTagName('*')]
      .map((node) => idName(attr(node, 'id'))).filter(Boolean);
    const duplicates = allIds.filter((id, index) => allIds.indexOf(id) !== index);
    if (duplicates.length) throw new Error('Duplicate XML ids: ' + [...new Set(duplicates)].join(', '));
    const missing = Object.keys(demo).filter((id) => !allIds.includes(id));
    if (missing.length) throw new Error('Expected ids missing from traffic_widget.xml: ' + missing.join(', '));

    const root = render(documentXml.documentElement);
    root.style.width = '384px';
    root.style.height = '280px';
    root.style.position = 'absolute';
    root.style.left = '0';
    root.style.top = '0';
    document.getElementById('widget-stage').appendChild(root);

    const visibleIds = Object.keys(demo).filter((id) => demo[id].visibility === 'visible');
    const hiddenSlots = ['slot_3', 'slot_4'].filter((id) => getComputedStyle(document.getElementById(id)).display !== 'none');
    const hiddenFields = ['slot_1_state', 'slot_1_phone', 'slot_1_balance', 'slot_1_summary', 'slot_2_state', 'slot_2_phone', 'slot_2_balance', 'slot_2_summary']
      .filter((id) => getComputedStyle(document.getElementById(id)).display !== 'none');
    const placeholderTexts = ['未连接', '运营商', '先在应用里选择运营商'];
    const shownPlaceholder = [...document.querySelectorAll('#widget-stage [data-native-type="TextView"]')]
      .find((element) => placeholderTexts.includes(element.textContent.trim()) && element.getClientRects().length > 0);
    if (hiddenSlots.length || hiddenFields.length || shownPlaceholder) {
      throw new Error('Preview visibility check failed: slots=' + hiddenSlots.join(',') + ', fields=' + hiddenFields.join(',') + ', placeholder=' + Boolean(shownPlaceholder));
    }
    window.__previewXmlIds = allIds.length;
    window.__previewExpectedIds = Object.keys(demo).length;
    window.__previewHiddenSlots = hiddenSlots;
    window.__previewHiddenFields = hiddenFields;
      } catch (error) {
        window.__previewError = String(error && (error.stack || error));
      }
    })();
  </script>
</body>
</html>`;

    await page.setContent(html, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts.ready);
    const report = await page.evaluate(() => {
      if (window.__previewError) throw new Error(window.__previewError);
      return {
        xmlIds: window.__previewXmlIds || 0,
        expectedIds: window.__previewExpectedIds || 0,
        hiddenSlots: window.__previewHiddenSlots || [],
        hiddenFields: window.__previewHiddenFields || [],
        title: document.querySelector('.preview-label')?.textContent,
        screenshotSize: '800x960 (400x480 logical pixels at 2x)',
        ids: [...document.querySelectorAll('[data-xml-id]')].map((node) => node.dataset.xmlId),
        cards: ['slot_1', 'slot_2'].map((id) => document.getElementById(id).getBoundingClientRect().toJSON()),
      };
    });
    if (!report.xmlIds || report.hiddenSlots.length || report.hiddenFields.length || report.title !== 'XML布局预览 · 合成数据 · 非手机实拍') {
      throw new Error('Rendered preview checks failed.');
    }
    if (report.cards.some((card) => card.width <= 0 || card.height <= 0)) throw new Error('One of the two cards has no visible layout bounds.');
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
    await page.screenshot({ path: outputPath });
    console.log(`XML ID check: ${report.xmlIds} IDs; ${Object.keys(demo).length} sample/visibility bindings present.`);
    console.log('Layout check: two cards visible; state, phone, balance, summary and unused slots hidden.');
    console.log(`Saved ${path.relative(root, outputPath)} (${report.screenshotSize}).`);
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exitCode = 1;
});
