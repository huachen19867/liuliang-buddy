// All official page URLs are intercepted locally. No account or server request.
const {chromium} = require('../.tools/browser/node_modules/playwright');
const fs = require('node:fs/promises');
const assert = require('node:assert/strict');
const home = 'https://wx.10086.cn/website/spa/main/newHome';

(async () => {
  const source = await fs.readFile('app/lib/services/page_probe.dart', 'utf8');
  const script = source.match(/const mobileBalanceCaptureScript = r'''([\s\S]*?)''';/)[1];
  const browser = await chromium.launch({headless: true,
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe'});
  const results = [];
  const scenarios = [
    {name: 'yuan', html: '<section><span>话费余额</span><b>12.34 元</b></section>', value: '12.34元'},
    {name: 'zero', html: '<section><span>账户余额</span><b>0元</b></section>', value: '0元'},
    {name: 'debt', html: '<section><span>话费余额</span><b>-2.50元</b></section>', value: '-2.50元'},
    {name: 'reversed', html: '<section><b>14.80元</b><span>话费余额</span></section>', value: '14.80元'},
    {name: 'nested-unit', html: '<section><header><span>话费余额</span></header><div><b>20.80</b><i>元</i></div></section>', value: '20.80元'},
    {name: 'fee-separate', html: '<section><span>实时费用</span><b>999元</b></section><section><span>话费余额</span><b>8元</b></section>', value: '8元'},
    {name: 'missing-yuan', html: '<section><span>话费余额</span><b>12.34</b></section>'},
    {name: 'wrong-unit', html: '<section><span>话费余额</span><b>12.34KB</b></section>'},
    {name: 'fee-only', html: '<section><span>本月费用</span><b>12.34元</b></section>'},
    {name: 'fee-mixed', html: '<section><span>话费余额</span><b>12元</b><span>实时费用</span><b>999元</b></section>'},
    {name: 'conflicting', html: '<section><span>话费余额</span><b>12元</b></section><section><span>账户余额</span><b>13元</b></section>'},
    {name: 'hidden-stale', html: '<section style="display:none"><span>话费余额</span><b>12元</b></section><section><span>话费余额</span><b>0元</b></section>', value: '0元'},
    {name: 'opacity-hidden', html: '<section style="opacity:0"><span>话费余额</span><b>12元</b></section>'},
    {name: 'wrong-page', url: 'https://wx.10086.cn/website/bind/bindAccount/new', html: '<section><span>话费余额</span><b>12元</b></section>'},
    {name: 'login-hash', url: home + '#/login', html: '<section><span>话费余额</span><b>12元</b></section>'},
    {name: 'subframe', html: '<iframe src="' + home + '?frame=1"></iframe>', frameHtml: '<section><span>话费余额</span><b>12元</b></section>'},
  ];
  try {
    for (const scenario of scenarios) {
      const page = await browser.newPage();
      await page.route('**/*', route => route.fulfill({status: 200,
        contentType: 'text/html; charset=utf-8', body: '<!doctype html><body>' +
          (route.request().url().includes('frame=1') ? scenario.frameHtml : scenario.html) + '</body>'}));
      const messages = [];
      await page.exposeFunction('receiveBalance', payload => messages.push(payload));
      await page.addInitScript(() => {
        window.flutter_inappwebview = {callHandler(name, payload) {
          return window.receiveBalance(payload);
        }};
      });
      await page.addInitScript(script);
      await page.goto(scenario.url || home, {waitUntil: 'load'});
      await page.waitForTimeout(400);
      const values = messages.map(message => JSON.parse(message.body).balanceText);
      assert.deepEqual(values, scenario.value ? [scenario.value] : [], scenario.name);
      results.push({name: scenario.name, passed: true, count: messages.length});
      await page.close();
    }
    const page = await browser.newPage();
    await page.route('**/*', route => route.fulfill({status: 200,
      contentType: 'text/html; charset=utf-8', body: '<!doctype html><body><section><span>话费余额</span><b id="value">12元</b></section><div id="churn"></div></body>'}));
    const messages = [];
    await page.exposeFunction('receiveBalance', payload => messages.push(payload));
    await page.addInitScript(() => {
      window.flutter_inappwebview = {callHandler(name, payload) {
        return window.receiveBalance(payload);
      }};
    });
    await page.addInitScript(script);
    await page.goto(home, {waitUntil: 'load'});
    await page.waitForTimeout(400);
    await page.evaluate(() => {
      window.churnTimer = setInterval(() => {
        document.querySelector('#churn').textContent = String(Math.random());
      }, 20);
    });
    await page.waitForTimeout(6500);
    await page.evaluate(() => {
      clearInterval(window.churnTimer);
      document.querySelector('#value').textContent = '0元';
    });
    await page.waitForTimeout(400);
    assert.equal(messages.length, 1, 'DOM churn cannot extend the fixed scan window');
    await page.evaluate(script);
    await page.waitForTimeout(100);
    assert.equal(messages.length, 2, 're-injection reads current DOM after deadline');
    assert.equal(JSON.parse(messages[1].body).balanceText, '0元');
    await page.evaluate(script);
    await page.waitForTimeout(100);
    assert.equal(messages.length, 3, 'new native query can receive the same current balance');
    results.push({name: 'fixed-window-and-reinjection', passed: true, count: messages.length});
    await page.close();
  } finally {
    await browser.close();
  }
  await fs.mkdir('artifacts', {recursive: true});
  await fs.writeFile('artifacts/mobile-balance-browser.json', JSON.stringify({
    source: 'production mobileBalanceCaptureScript, local intercepted Chrome pages',
    officialRequests: 0, realAccountVerified: false, scenarios: results,
  }, null, 2) + '\n');
  console.log('PASS: ' + results.length + ' local Chrome mobile balance scenarios');
})().catch(error => {console.error(error); process.exitCode = 1;});
