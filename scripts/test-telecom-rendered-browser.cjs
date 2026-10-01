// Real Chrome, entirely synthetic HTML based on the public Account template.
// All browser network requests are fulfilled/aborted locally. No account/API use.
const {chromium} = require(process.env.LIULIANG_PLAYWRIGHT_MODULE ||
  '../.tools/browser/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const target = 'https://e.dlife.cn/portal/web/index.html';
const row = (name, text, type = '3') => `<div class="list"><span class="bill-title">${name}</span>` +
  `<span class="end-time-text">失效时间：2099/12/31</span>` +
  `<span class="bill-balance" data-id="${type}">${text}</span></div>`;
const modal = rows => `<div id="balanceModal" style="display:none"><div class="modal-body">` +
  `<div class="bill-list">${rows}</div></div></div>`;

(async () => {
  const source = await fs.readFile(path.join(__dirname,
    '../app/lib/services/telecom_page_probe.dart'), 'utf8');
  const match = source.match(/const telecomRenderedCaptureScript = r'''([\s\S]*?)''';/);
  assert.ok(match, 'read current application probe');
  const browser = await chromium.launch({headless: true,
    ...(process.env.LIULIANG_CHROME_PATH ?
      {executablePath: process.env.LIULIANG_CHROME_PATH} : {channel: 'chrome'})});
  const cases = [];
  let fulfilled = 0;
  let aborted = 0;
  async function fixture(html, {hash = '#/', bridge = true} = {}) {
    const context = await browser.newContext();
    await context.route('**/*', route => {
      if (route.request().isNavigationRequest() &&
          route.request().url().split('#')[0] === target) {
        fulfilled++;
        return route.fulfill({status: 200, contentType: 'text/html; charset=utf-8',
          body: `<!doctype html><html><head><meta charset="utf-8"></head><body>${html}</body></html>`});
      }
      aborted++;
      return route.abort();
    });
    const messages = [];
    const page = await context.newPage();
    await page.exposeFunction('captureTest', (name, payload) => {
      assert.equal(name, 'trafficResponse');
      messages.push(payload);
    });
    await context.addInitScript(`${bridge ?
      'window.flutter_inappwebview={callHandler:(...args)=>window.captureTest(...args)};' : ''}\n${match[1]}`);
    await page.goto(target + hash);
    await page.waitForTimeout(450);
    return {context, page, messages};
  }
  const sample = modal(row('测试套餐', ' 已使用<span class="blue-font">512MB</span> / 2GB') +
    row('语音', '已使用10分钟 / 100分钟', '1') + row('短信', '已使用1次 / 20次', '2'));
  try {
    for (const [label, value, unit, expected] of [
      ['余额:', '12.30', '元', '12.30 元'],
      ['余额:', '-2.50', '元', '-2.50 元'],
      ['当月费用:', '12.30', '元', undefined],
      ['余额:', '123', 'KB', undefined],
      ['余额:', '--', '元', undefined],
    ]) {
      const money = `<span>${label}<b id="mobileBalance">${value}</b></span>${unit}`;
      const f = await fixture(sample.replace('<div class="modal-body">',
        `<div class="modal-body">${money}`));
      assert.equal(JSON.parse(f.messages[0].body).balanceText, expected);
      await f.context.close();
    }
    cases.push('exact official balance label, signed yuan, ambiguous money rejected');
    let f = await fixture(sample);
    assert.equal(await f.page.locator('#balanceModal').isVisible(), false);
    assert.equal(f.messages.length, 1, 'hidden v-show modal captured without clicking');
    let data = JSON.parse(f.messages[0].body);
    assert.equal(f.messages[0].stage, 'telecomRendered');
    assert.deepEqual(data, {source: 'officialRendered', rows: [{name: '测试套餐', used: '512MB', total: '2GB'}],
      allowanceRows: [{kind: 'voice', name: '语音', used: '10分钟', total: '100分钟'},
        {kind: 'sms', name: '短信', used: '1次', total: '20次'}]});
    cases.push('hidden modal, mixed units/NBSP, separate voice/SMS rows');
    const before = f.messages.length;
    await f.page.evaluate(() => {location.hash = '#/login';});
    await f.page.locator('.bill-title').first().evaluate(e => {e.textContent = 'stale account';});
    await f.page.waitForTimeout(450);
    assert.equal(f.messages.length, before, 'SPA login never emits retained Home rows');
    cases.push('SPA Home to login suppresses stale rows');
    await f.context.close();

    f = await fixture(sample, {hash: '#/login'});
    assert.equal(f.messages.length, 0);
    cases.push('initial login route rejected');
    await f.context.close();

    f = await fixture(`<section class="promotion">${row('营销流量', '已使用0GB / 100GB')}</section>`);
    assert.equal(f.messages.length, 0);
    cases.push('similar marketing text outside exact container rejected');
    await f.context.close();

    f = await fixture(sample, {bridge: false});
    assert.equal(f.messages.length, 0);
    await f.page.evaluate(() => {
      window.flutter_inappwebview = {callHandler: (...args) => window.captureTest(...args)};
      window.dispatchEvent(new Event('flutterInAppWebViewPlatformReady'));
    });
    await f.page.waitForTimeout(100);
    assert.equal(f.messages.length, 1);
    cases.push('late bridge ready flushes captured rows once');
    await f.context.close();

    f = await fixture(modal(row('完整套餐', '已使用1GB / 2GB') + row('未完整套餐', '已使用-- / 3GB')));
    data = JSON.parse(f.messages[0].body);
    assert.equal(data.rows.length, 2);
    assert.deepEqual(data.rows[1], {name: '未完整套餐', used: null, total: null});
    assert.equal('remaining' in data, false, 'probe does not invent an aggregate');
    cases.push('incomplete row preserved as null without synthesized aggregate');
    await f.context.close();

    f = await fixture(modal(row('不限量测试套餐', '已使用512MB / 不限量')));
    data = JSON.parse(f.messages[0].body);
    assert.deepEqual(data.rows, [{name: '不限量测试套餐', used: '512MB', total: '不限量'}]);
    assert.equal('remaining' in data, false, 'unlimited marker never becomes a fabricated byte balance');
    cases.push('explicit unlimited total preserved for terminal Dart parsing');
    await f.context.close();

    f = await fixture(sample, {bridge: false});
    await f.page.evaluate(() => {
      location.hash = '#/login';
      window.flutter_inappwebview = {callHandler: (...args) => window.captureTest(...args)};
      window.dispatchEvent(new Event('flutterInAppWebViewPlatformReady'));
    });
    await f.page.waitForTimeout(450);
    assert.equal(f.messages.length, 0, 'queued Home rows discarded when bridge becomes ready on login');
    cases.push('login invalidates pending bridge payload');
    await f.context.close();
    f = await fixture(modal(row('国内通话', '已使用10分钟 / 100分钟', '1') +
      row('未知业务', '已使用1次 / 20次', '2') + row('短信', '已使用-- / 20条', '2')));
    data = JSON.parse(f.messages[0].body);
    assert.deepEqual(data.rows, []);
    assert.deepEqual(data.allowanceRows, [
      {kind: 'voice', name: '国内通话', used: '10分钟', total: '100分钟'},
      {kind: 'sms', name: '短信', used: null, total: null}]);
    cases.push('voice-only response emitted, ambiguous type2 excluded, missing SMS preserved');
    await f.context.close();
    f = await fixture(sample, {bridge: false});
    await f.page.locator('#balanceModal .bill-list').evaluate(e => e.replaceChildren());
    await f.page.evaluate(() => {
      window.flutter_inappwebview = {callHandler: (...args) => window.captureTest(...args)};
      window.dispatchEvent(new Event('flutterInAppWebViewPlatformReady'));
    });
    await f.page.waitForTimeout(450);
    assert.equal(f.messages.length, 0, 'cleared official component cannot replay queued balances');
    cases.push('removed official rows invalidate pending bridge payload');
    await f.context.close();
    const report = {passed: true, syntheticOnly: true, actualAccountVerified: false,
      networkPolicy: 'Every browser request fulfilled or aborted locally', fulfilled, aborted, cases};
    const directory = path.join(__dirname, '../artifacts');
    await fs.mkdir(directory, {recursive: true});
    await fs.writeFile(path.join(directory, 'telecom-rendered-browser.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify(report, null, 2));
  } finally {await browser.close();}
})().catch(error => {console.error(error); process.exitCode = 1;});
