// Public browser investigation. Synthetic response is intercepted locally only.
const {chromium} = require(process.env.LIULIANG_PLAYWRIGHT_MODULE ||
  '../.tools/browser/node_modules/playwright');
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const delayedBridge = process.argv.includes('--delayed-bridge');
const queryEpochTest = process.argv.includes('--query-epoch');
(async () => {
  const source = await fs.readFile(path.join(__dirname,
    '../app/lib/services/page_probe.dart'), 'utf8');
  const script = source.match(/const responseCaptureScript = r'''([\s\S]*?)''';/)[1];
  const browser = await chromium.launch({headless: true,
    ...(process.env.LIULIANG_CHROME_PATH ?
      {executablePath: process.env.LIULIANG_CHROME_PATH} : {channel: 'chrome'})});
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    const messages = [];
    await page.exposeFunction('reviewCapture', (name, payload) => {
      messages.push({name, ...payload});
    });
    await context.addInitScript(`${delayedBridge ? '' : 'window.flutter_inappwebview = {callHandler: (...args) => window.reviewCapture(...args)};'}\n${script}`);
    await page.goto('https://www.10099.com.cn/login.html', {waitUntil: 'domcontentloaded'});
    await page.waitForTimeout(3000);
    await page.evaluate(() => {
      // Research-only: inspect the public bundle's existing module, no new API request.
      window.webpackJsonp([], {reviewProbe: function(module, exports, require) {
        window.reviewBusinessJQuery = require(0);
      }}, ['reviewProbe']);
    });
    const metadata = await page.evaluate(() => ({
      url: location.href, jquery: typeof window.jQuery,
      version: window.jQuery?.fn?.jquery,
      ajaxGlobal: window.jQuery?.ajaxSettings?.global,
      filter: typeof window.jQuery?.ajaxSettings?.dataFilter,
      http: typeof window.jQuery?.http,
      businessSameInstance: window.reviewBusinessJQuery === window.jQuery,
      businessVersion: window.reviewBusinessJQuery?.fn?.jquery,
      businessFilter: typeof window.reviewBusinessJQuery?.ajaxSettings?.dataFilter,
      businessGlobal: window.reviewBusinessJQuery?.ajaxSettings?.global,
      scripts: [...document.scripts].map(s=>s.src),
      probe: window.__liuliangResponseProbe,
      eventNames: Object.keys(window.jQuery?._data(document, 'events') || {}),
    }));
    const synthetic = {status:'000000', data:{respCode:'000000',
      intfResultBean:{userResList:[{busiType:'5',discntName:'测试通用流量', highFee:'1048576', balance:'524288'}]}}};
    if (queryEpochTest) await page.evaluate(() => {
      window.__liuliangQueryEpoch = 'round-browser-request';
    });
    await page.route('**/contact-web/api/busi/qryUserRes', async route => {
      if (queryEpochTest) await page.evaluate(() => {
        window.__liuliangQueryEpoch = 'round-browser-response';
      });
      return route.fulfill({
        status:200, contentType:'application/json', body:JSON.stringify(synthetic)});
    });
    const ajaxResult = await page.evaluate(() => new Promise(resolve => {
      window.reviewBusinessJQuery.ajax({url:'/contact-web/api/busi/qryUserRes', type:'GET', dataType:'json'})
        .done((data, status, xhr) => resolve({data, responseJSON:xhr.responseJSON}))
        .fail((xhr,status,error) => resolve({status,error:String(error)}));
    }));
    await page.waitForTimeout(200);
    if (delayedBridge) {
      assert.equal(messages.length, 0, 'bridge absent before readiness');
      await page.evaluate(() => {
        if (window.__liuliangQueryEpoch)
          window.__liuliangQueryEpoch = 'round-browser-ready';
        window.flutter_inappwebview = {callHandler: (...args) => window.reviewCapture(...args)};
        window.dispatchEvent(new Event('flutterInAppWebViewPlatformReady'));
      });
      await page.waitForTimeout(200);
    }
    assert.equal(metadata.businessSameInstance, false);
    assert.deepEqual(ajaxResult.data, synthetic.data, 'official dataFilter result preserved');
    const decoded = messages.filter(message => message.stage === 'officialDecoded');
    assert.equal(decoded.length, 1, 'business instance captured exactly once');
    assert.deepEqual(JSON.parse(decoded[0].body), synthetic.data);
    if (queryEpochTest) {
      assert.equal(decoded[0].queryEpoch, 'round-browser-request',
        'real private jQuery result and queue retain request-start epoch');
      const raw = messages.filter(message => message.stage === 'raw');
      assert.equal(raw.length, 1);
      assert.equal(raw[0].queryEpoch, 'round-browser-request',
        'real XHR retains send epoch through intercepted late response');
    } else {
      assert.equal(Object.hasOwn(decoded[0], 'queryEpoch'), false);
    }
    console.log(JSON.stringify({syntheticOnly: true, delayedBridge, passed: true,
      queryEpochTest,
      globalJQuery: metadata.version, businessJQuery: metadata.businessVersion,
      decodedEvents: decoded.length}));
  } finally {await browser.close();}
})().catch(error => {console.error(error);process.exitCode=1;});
