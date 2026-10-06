// Run: node test/services/telecom_epoch_probe_js_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
  '../../lib/services/telecom_page_probe.dart'), 'utf8');
const script = source.match(/const telecomRenderedCaptureScript = r'''([\s\S]*?)''';/)[1];

function setup({bridgeReady = true, queryEpoch} = {}) {
  const messages = [];
  const listeners = new Map();
  const timers = new Map();
  let nextTimer = 0;
  let rows = true;
  const balance = {textContent: '已使用1GB / 2GB', getAttribute: () => '3'};
  const name = {textContent: '国内上网流量'};
  const element = {querySelector: selector => selector === '.bill-title' ? name : balance};
  const bridge = {callHandler(handler, payload) {
    assert.equal(handler, 'trafficResponse');
    messages.push(payload); return Promise.resolve();
  }};
  const context = {
    location: {origin: 'https://e.dlife.cn', pathname: '/portal/web/index.html',
      hash: '#/', href: 'https://e.dlife.cn/portal/web/index.html#/'},
    document: {body: {}, readyState: 'complete',
      querySelectorAll: () => rows ? [element] : [], querySelector: () => null,
      addEventListener() {}},
    addEventListener(name, callback) { listeners.set(name, callback); },
    setTimeout(callback) { const id = ++nextTimer; timers.set(id, callback); return id; },
    MutationObserver: class { observe() {} },
    Promise,
  };
  context.window = context; context.top = context;
  if (queryEpoch !== undefined) context.__liuliangQueryEpoch = queryEpoch;
  if (bridgeReady) context.flutter_inappwebview = bridge;
  vm.runInNewContext(script, context);
  const tick = () => {
    const callbacks = [...timers.values()]; timers.clear();
    callbacks.forEach(callback => callback());
  };
  tick();
  return {context, messages, name, tick,
    clearRows() { rows = false; },
    ready() {
      context.flutter_inappwebview = bridge;
      listeners.get('flutterInAppWebViewPlatformReady')();
    },
  };
}

const legacy = setup();
assert.equal(legacy.messages.length, 1);
assert.equal(Object.hasOwn(legacy.messages[0], 'queryEpoch'), false,
  'legacy documents do not gain an undefined epoch field');

const delayed = setup({bridgeReady: false, queryEpoch: 'round-capture'});
assert.equal(delayed.messages.length, 0);
delayed.context.__liuliangQueryEpoch = 'round-ready';
delayed.ready();
assert.equal(delayed.messages.length, 1);
assert.equal(delayed.messages[0].queryEpoch, 'round-capture',
  'bridge-ready event must not rebind already queued DOM rows');
delayed.context.__liuliangTelecomRescan();
assert.equal(delayed.messages.length, 2);
assert.equal(delayed.messages[1].queryEpoch, 'round-ready',
  'an explicit SPA rescan reads fresh DOM for its current epoch');
assert.equal(delayed.messages[0].queryEpoch, 'round-capture',
  'new DOM scan does not mutate previously delivered payload');

const login = setup({bridgeReady: false, queryEpoch: 'round-home'});
login.context.location.hash = '#/login';
login.context.__liuliangQueryEpoch = 'round-login';
login.ready();
assert.equal(login.messages.length, 0, 'login discards queued Home rows');
const cleared = setup({bridgeReady: false, queryEpoch: 'round-before-clear'});
cleared.clearRows();
cleared.ready();
assert.equal(cleared.messages.length, 0,
  'bridge ready validates component existence before flushing queued rows');
console.log('PASS: Telecom DOM epoch, immutable deferred payload, explicit SPA rescan and legacy/login guards');
