// Run: node test/services/page_probe_js_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
  '../../lib/services/page_probe.dart'), 'utf8');
const script = source.match(/const responseCaptureScript = r'''([\s\S]*?)''';/)[1];

function setup(origin, {subframe = false, brokenBridge = false} = {}) {
  const messages = [];
  const calls = [];
  let lastPromise;
  let lastResponse;
  const jqHandlers = [];
  const jquery = () => ({on(name, callback) { jqHandlers.push({name, callback}); }});
  jquery.fn = {on() {}};
  class XHR {
    constructor() { this.listeners = []; this.responseType = ''; }
    open(...args) { this.openArgs = args; return 'open-result'; }
    addEventListener(type, fn) { assert.equal(type, 'load'); this.listeners.push(fn); }
    send(...args) { this.sendArgs = args; return 'send-result'; }
    complete(url, body = '{}', status = 200) {
      this.responseURL = url; this.responseText = body; this.status = status;
      this.listeners.splice(0).forEach(fn => fn());
    }
  }
  const context = {
    URL, Promise, WeakMap, XMLHttpRequest: XHR,
    jQuery: jquery,
    document: {addEventListener() {}, removeEventListener() {}},
    setInterval, clearInterval,
    location: {origin, href: origin + '/query.html'},
    flutter_inappwebview: {callHandler(name, payload) {
      if (brokenBridge) return Promise.reject(new Error('bridge failed'));
      messages.push({name, payload}); return Promise.resolve();
    }},
    fetch(...args) {
      calls.push({args, receiver: this});
      lastResponse = {url: new URL(args[0], origin).href, status: 200,
        clone() { return {text: () => Promise.resolve('{"data":1}')}; }};
      lastPromise = Promise.resolve(lastResponse);
      return lastPromise;
    },
  };
  context.window = context;
  context.top = subframe ? {} : context;
  const originalFetch = context.fetch;
  vm.runInNewContext(script, context);
  return {context, XHR, messages, calls, originalFetch,
    jqHandlers, promise: () => lastPromise, response: () => lastResponse};
}
const settle = () => new Promise(resolve => setImmediate(resolve));

(async () => {
  const mobile = setup('https://wx.10086.cn');
  const options = {method: 'GET', credentials: 'include'};
  const pending = mobile.context.fetch('/website/getNewMarginInfo', options);
  assert.equal(pending, mobile.promise(), 'return original promise');
  assert.equal(await pending, mobile.response(), 'return original response');
  assert.equal(mobile.calls[0].args[1], options, 'retain original options');
  await settle();
  assert.equal(mobile.messages.length, 1);
  assert.equal(mobile.messages[0].name, 'trafficResponse');
  assert.equal(mobile.messages[0].payload.pageUrl, 'https://wx.10086.cn/query.html');
  for (const url of ['/sendSms', '/login', 'https://evil.test/getNewMarginInfo',
    'https://wx.10086.cn.evil.test/getNewMarginInfo',
    'https://wx.10099.com.cn/qryUserRes']) await mobile.context.fetch(url);
  await settle();
  assert.equal(mobile.messages.length, 1, 'do not capture login/SMS/untrusted responses');

  const xhr = new mobile.XHR();
  assert.equal(xhr.open('GET', '/getNewMarginInfo', true), 'open-result');
  assert.deepEqual(xhr.openArgs, ['GET', '/getNewMarginInfo', true]);
  const requestBody = {original: true};
  assert.equal(xhr.send(requestBody), 'send-result');
  assert.equal(xhr.sendArgs[0], requestBody);
  xhr.complete('https://wx.10086.cn/getNewMarginInfo', '{"used":4}');
  assert.equal(mobile.messages.length, 2);
  assert.equal(xhr.responseText, '{"used":4}', 'retain official response');

  const broadnet = setup('https://www.10099.com.cn');
  await broadnet.context.fetch('/qryUserRes');
  await broadnet.context.fetch('https://wx.10099.com.cn/contact-web/api/busi/qryUserRes');
  await broadnet.context.fetch('https://other.10099.com.cn/qryUserRes');
  await broadnet.context.fetch('https://wx.10099.com.cn/login');
  await settle();
  assert.equal(broadnet.messages.length, 2, 'only exact Broadnet API origins');
  assert.equal(broadnet.jqHandlers.length, 1);
  const official = {respCode: '000000', intfResultBean: {userResList: []}};
  const officialXhr = {responseJSON: official, status: 200};
  const settings = {url: '/contact-web/api/busi/qryUserRes'};
  broadnet.jqHandlers[0].callback({}, officialXhr, settings, official);
  assert.equal(broadnet.messages.at(-1).payload.stage, 'officialDecoded');
  assert.deepEqual(JSON.parse(broadnet.messages.at(-1).payload.body), official);
  assert.equal(officialXhr.responseJSON, official, 'do not replace jQuery result');
  const count = broadnet.messages.length;
  broadnet.jqHandlers[0].callback({}, officialXhr, {url: '/login'}, official);
  assert.equal(broadnet.messages.length, count, 'do not capture other jQuery responses');
  const expired = {status: '701', message: '登录已过期，请重新登录', data: null};
  const expiredXhr = new broadnet.XHR();
  expiredXhr.open('POST', '/contact-web/api/busi/qryUserRes');
  expiredXhr.send();
  expiredXhr.complete('https://www.10099.com.cn/contact-web/api/busi/qryUserRes',
    JSON.stringify(expired));
  assert.deepEqual(JSON.parse(broadnet.messages.at(-1).payload.body), expired,
    'forward actual auth expiry without fabricated success');
  assert.equal(broadnet.messages.at(-1).payload.stage, 'raw');

  for (const fixture of [setup('https://evil.test'), setup('http://wx.10086.cn'),
    setup('https://wx.10086.cn', {subframe: true})]) {
    assert.equal(fixture.context.fetch, fixture.originalFetch, 'do not hook unauthorized contexts');
  }
  const broken = setup('https://wx.10086.cn', {brokenBridge: true});
  const response = await broken.context.fetch('/getNewMarginInfo');
  await settle();
  assert.equal(response, broken.response(), 'bridge errors do not affect requests');
  console.log('PASS: fetch/XHR fidelity, bridge filtering, Broadnet allowlist, origin/frame guards');
})().catch(error => { console.error(error); process.exitCode = 1; });
