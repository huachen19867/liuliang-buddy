// Run: node test/services/page_probe_js_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
  '../../lib/services/page_probe.dart'), 'utf8');
const script = source.match(/const responseCaptureScript = r'''([\s\S]*?)''';/)[1];

function setup(origin, {subframe = false, brokenBridge = false, bridgeReady = true, pathname = '/query.html'} = {}) {
  const messages = [];
  const calls = [];
  let lastPromise;
  let lastResponse;
  const jqHandlers = [];
  const documentListeners = new Map();
  const windowListeners = new Map();
  const timers = new Map();
  let nextTimer = 0;
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
    URL, Promise, WeakMap, WeakSet, XMLHttpRequest: XHR,
    jQuery: jquery,
    document: {
      addEventListener(name, fn) { documentListeners.set(name, fn); },
      removeEventListener(name) { documentListeners.delete(name); },
    },
    addEventListener(name, fn) { windowListeners.set(name, fn); },
    setInterval(fn) { const id = ++nextTimer; timers.set(id, fn); return id; },
    clearInterval(id) { timers.delete(id); },
    location: {origin, href: origin + pathname, pathname},
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
  const bridge = context.flutter_inappwebview;
  if (!bridgeReady) delete context.flutter_inappwebview;
  const originalFetch = context.fetch;
  vm.runInNewContext(script, context);
  return {context, XHR, messages, calls, originalFetch,
    jqHandlers, promise: () => lastPromise, response: () => lastResponse,
    scriptLoad() { documentListeners.get('load')?.({target: {tagName: 'SCRIPT'}}); },
    ready() {
      context.flutter_inappwebview = bridge;
      windowListeners.get('flutterInAppWebViewPlatformReady')?.();
    },
    tick() { for (const fn of [...timers.values()]) fn(); },
  };
}
const settle = () => new Promise(resolve => setImmediate(resolve));

(async () => {
  const unicom = setup('https://iservice.10010.com', {pathname:'/e5/index.html'});
  await unicom.context.fetch('/e3/static/query/userinfoE5query?_=1');
  await settle();
  assert.equal(unicom.messages.length, 1);
  for (const url of ['/e3/static/check/checklogin/', '/sendSms', '/e3/static/query/userinfoE5queryExtra',
    'https://iservice.10010.com.evil.test/e3/static/query/userinfoE5query']) await unicom.context.fetch(url);
  await settle();
  assert.equal(unicom.messages.length, 1, 'Unicom only observes its official balance response');
  const unicomLogin = setup('https://iservice.10010.com', {pathname:'/login.html'});
  await unicomLogin.context.fetch('/e3/static/query/userinfoE5query');
  await settle();
  assert.equal(unicomLogin.messages.length, 0, 'Unicom unrelated pages do not forward personal data');
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

  // Reproduce the real site: WAF global jQuery and a separate webpack module 0.
  const privateSite = setup('https://www.10099.com.cn');
  const privateHandlers = [];
  const privateJq = () => ({on(name, callback) { privateHandlers.push({name, callback}); }});
  privateJq.fn = {on() {}, jquery: '3.6.0'};
  let registered;
  let runtimeReceiver;
  let runtimeArgs;
  const runtimeResult = {};
  privateSite.context.webpackJsonp = function(...args) {
    runtimeReceiver = this; runtimeArgs = args; registered = args[1];
    return runtimeResult;
  };
  privateSite.scriptLoad(); // polyfill defines JSONP before vendor registers.
  const module = {exports: {}};
  const factoryResult = {};
  let runs = 0;
  let factoryReceiver;
  let factoryArgs;
  const modules = [function(...args) {
    runs++; factoryReceiver = this; factoryArgs = args;
    args[0].exports = privateJq;
    return factoryResult;
  }];
  const receiver = {};
  const chunkIds = [2];
  const entryIds = [];
  assert.equal(privateSite.context.webpackJsonp.call(receiver, chunkIds, modules, entryIds), runtimeResult);
  assert.equal(runtimeReceiver, receiver);
  assert.equal(runtimeArgs[0], chunkIds);
  assert.equal(runtimeArgs[1], modules);
  assert.equal(runtimeArgs[2], entryIds);
  assert.equal(runs, 0, 'do not initialize website modules early');
  const exports = module.exports;
  const require = () => {};
  assert.equal(registered[0].call(receiver, module, exports, require), factoryResult);
  assert.equal(runs, 1, 'execute original factory exactly once');
  assert.equal(factoryReceiver, receiver);
  assert.deepEqual(factoryArgs, [module, exports, require]);
  assert.equal(module.exports, privateJq);
  assert.equal(privateHandlers.length, 1);
  privateSite.scriptLoad();
  privateSite.tick();
  assert.equal(privateSite.jqHandlers.length, 1, 'deduplicate global instance');
  assert.equal(privateHandlers.length, 1, 'deduplicate private instance');
  privateHandlers[0].callback({}, officialXhr, settings, official);
  assert.equal(privateSite.messages.at(-1).payload.stage, 'officialDecoded');
  assert.deepEqual(JSON.parse(privateSite.messages.at(-1).payload.body), official);
  assert.equal(officialXhr.responseJSON, official, 'retain official decoded object');

  const delayed = setup('https://www.10099.com.cn', {bridgeReady: false});
  delayed.jqHandlers[0].callback({}, officialXhr, settings, official);
  assert.equal(delayed.messages.length, 0);
  delayed.ready();
  assert.equal(delayed.messages.length, 1, 'deliver early decoded result after native bridge readiness');
  assert.deepEqual(JSON.parse(delayed.messages[0].payload.body), official);
  delayed.ready();
  assert.equal(delayed.messages.length, 1, 'ready event does not replay delivered results');
  const bounded = setup('https://www.10099.com.cn', {bridgeReady: false});
  for (let i = 0; i < 12; i++) {
    bounded.jqHandlers[0].callback({}, {responseJSON: {index: i}, status: 200}, settings, {});
  }
  bounded.ready();
  assert.equal(bounded.messages.length, 8, 'early response queue is bounded');
  assert.equal(JSON.parse(bounded.messages[0].payload.body).index, 4);

  for (const fixture of [setup('https://evil.test'), setup('http://wx.10086.cn'),
    setup('https://wx.10086.cn', {subframe: true})]) {
    assert.equal(fixture.context.fetch, fixture.originalFetch, 'do not hook unauthorized contexts');
  }
  const broken = setup('https://wx.10086.cn', {brokenBridge: true});
  const response = await broken.context.fetch('/getNewMarginInfo');
  await settle();
  assert.equal(response, broken.response(), 'bridge errors do not affect requests');
  console.log('PASS: fetch/XHR fidelity, private business jQuery, deferred bridge, bounded queue, origin/frame guards');
})().catch(error => { console.error(error); process.exitCode = 1; });
