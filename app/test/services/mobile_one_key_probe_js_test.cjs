// Run: node test/services/mobile_one_key_probe_js_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
  '../../lib/services/page_probe.dart'), 'utf8');
const script = source.match(/const mobileOneKeyProbeScript = r'''([\s\S]*?)''';/)[1];

function setup({pathname = '/website/bind/bindAccount/new',
  origin = 'https://wx.10086.cn', subframe = false, ready = true,
  popupVisible = true, popupPresent = true, mask = '138****1234'} = {}) {
  const messages = [];
  const timers = new Map();
  const listeners = new Map();
  let nextTimer = 0;
  const phone = {nodeType: 1, textContent: mask};
  const popup = {
    nodeType: 1,
    style: {display: popupVisible ? 'block' : 'none',
      visibility: 'visible', opacity: '1'},
    getClientRects() { return popupVisible ? [{}] : []; },
  };
  const bridge = {callHandler(name, payload) {
    messages.push({name, payload}); return Promise.resolve();
  }};
  const context = {
    location: {origin, pathname, href: origin + pathname},
    document: {
      querySelector(selector) {
        if (selector === '.onekeyLoginPop') return popupPresent ? popup : null;
        if (selector === '#onekeyLoginPhone') return phone;
        return null;
      },
    },
    getComputedStyle: node => node.style,
    Promise, Set,
    setInterval(fn) { const id = ++nextTimer; timers.set(id, fn); return id; },
    clearInterval(id) { timers.delete(id); },
    addEventListener(name, callback) { listeners.set(name, callback); },
    flutter_inappwebview: ready ? bridge : undefined,
  };
  context.window = context;
  context.top = subframe ? {} : context;
  vm.runInNewContext(script, context);
  return {messages, context, phone, popup, timers, listeners,
    tick() { for (const callback of [...timers.values()]) callback(); },
    ready() { context.flutter_inappwebview = bridge;
      listeners.get('flutterInAppWebViewPlatformReady')?.(); },
  };
}

const reported = setup();
assert.equal(reported.messages.length, 1);
assert.equal(reported.messages[0].name, 'oneKeyPrompt');
assert.equal(reported.messages[0].payload.maskedPhone, '138****1234');
assert.equal(reported.messages[0].payload.pageUrl,
  'https://wx.10086.cn/website/bind/bindAccount/new');
assert.equal(Object.hasOwn(reported.messages[0].payload, 'queryEpoch'), false,
  'login observation is not a query round response');
reported.tick();
assert.equal(reported.messages.length, 1, 'unchanged popup is not re-sent');
reported.tick();
assert.equal(reported.messages.length, 1);

reported.phone.textContent = '138****5678';
reported.tick();
assert.equal(reported.messages.length, 2, 'changed mask is reported');
assert.equal(reported.messages[1].payload.maskedPhone, '138****5678');

reported.popup.style.display = 'none';
reported.tick();
assert.equal(reported.messages.length, 2);
reported.popup.style.display = 'block';
reported.tick();
assert.equal(reported.messages.length, 3,
  'a new popup appearance re-reports the current mask');
assert.equal(reported.messages[2].payload.maskedPhone, '138****5678');

for (const [label, options] of [
  ['absent popup', {popupPresent: false}],
  ['hidden popup', {popupVisible: false}],
  ['empty mask', {mask: ''}],
  ['loading text without digits', {mask: '正在取号…'}],
  ['unreasonably long mask', {mask: '1'.repeat(33)}],
  ['other official page', {pathname: '/website/spa/main/newHome'}],
  ['other origin', {origin: 'https://wx.10086.cn.evil.test'}],
  ['plain http', {origin: 'http://wx.10086.cn'}],
  ['subframe', {subframe: true}],
]) {
  const fixture = setup(options);
  fixture.tick(); fixture.tick();
  assert.equal(fixture.messages.length, 0, label);
}

const spaced = setup({mask: ' 138 **** 1234 '});
assert.equal(spaced.messages.length, 1);
assert.equal(spaced.messages[0].payload.maskedPhone, '138****1234',
  'official whitespace inside the mask is normalized');

const lateBridge = setup({ready: false});
lateBridge.tick(); lateBridge.tick();
assert.equal(lateBridge.messages.length, 0);
lateBridge.ready();
assert.equal(lateBridge.messages.length, 1,
  'bridge readiness delivers the currently visible popup');
lateBridge.ready();
assert.equal(lateBridge.messages.length, 1,
  'ready event does not replay delivered results');

const leaving = setup();
assert.equal(leaving.timers.size, 1);
leaving.context.location.pathname = '/website/spa/main/newHome';
leaving.tick();
assert.equal(leaving.timers.size, 0,
  'navigation away from the login route stops the poll');
console.log('PASS: one-key popup visibility, masked number dedup and re-report, page and frame guards, late bridge, bounded poll');
