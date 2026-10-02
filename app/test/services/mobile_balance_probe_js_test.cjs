// Run: node test/services/mobile_balance_probe_js_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
  '../../lib/services/page_probe.dart'), 'utf8');
const script = source.match(/const mobileBalanceCaptureScript = r'''([\s\S]*?)''';/)[1];

function setup({tiles = [['话费余额', '12.34 元']], pathname = '/website/spa/main/newHome',
  origin = 'https://wx.10086.cn', hash = '', subframe = false, ready = true} = {}) {
  const messages = [];
  const timers = new Map();
  const listeners = new Map();
  let observers = [];
  let now = 0;
  let nextTimer = 0;
  let elements = [];
  const create = (text, options = {}) => ({
    nodeType: 1, textContent: text, innerText: text, parentElement: null,
    style: {display: 'block', visibility: 'visible', opacity: '1', ...options.style},
    hidden: options.hidden || false,
    getClientRects() { return this.layoutHidden ? [] : [{}]; },
    getAttribute(name) { return name === 'aria-hidden' && this.ariaHidden ? 'true' : null; },
  });
  const setTiles = rows => {
    elements = [];
    for (const [labelText, amountText, options = {}] of rows) {
      const container = create(`${labelText}\n${amountText}`, options);
      const label = create(labelText);
      const amount = create(amountText);
      label.parentElement = container;
      amount.parentElement = container;
      elements.push(container, label, amount);
    }
  };
  setTiles(tiles);
  const bridge = {callHandler(name, payload) {
    messages.push({name, payload}); return Promise.resolve();
  }};
  const context = {
    location: {origin, pathname, hash, href: origin + pathname + hash},
    document: {documentElement: {}, querySelectorAll() { return elements; }},
    getComputedStyle: node => node.style,
    MutationObserver: class {
      constructor(callback) { this.callback = callback; this.active = false; observers.push(this); }
      observe() { this.active = true; }
      disconnect() { this.active = false; }
    },
    Date: {now: () => now}, Promise, Set,
    setInterval(fn) { const id = ++nextTimer; timers.set(id, fn); return id; },
    clearInterval(id) { timers.delete(id); },
    addEventListener(name, callback) { listeners.set(name, callback); },
    flutter_inappwebview: ready ? bridge : undefined,
  };
  context.window = context;
  context.top = subframe ? {} : context;
  const run = () => vm.runInNewContext(script, context);
  run();
  return {messages, context, elements: () => elements, setTiles, timers,
    run, mutation() { for (const observer of observers) if (observer.active) observer.callback(); },
    tick(ms = 200) { now += ms; for (const callback of [...timers.values()]) callback(); },
    ready() { context.flutter_inappwebview = bridge; listeners.get('flutterInAppWebViewPlatformReady')?.(); },
    activeObservers: () => observers.filter(observer => observer.active).length,
  };
}

for (const [label, value, expected] of [
  ['话费余额', '12.34 元', '12.34元'], ['账户余额', '0 元', '0元'],
  ['话费余额', '-2.50元', '-2.50元'], ['12.34元', '话费余额', '12.34元'],
]) {
  const fixture = setup({tiles: [[label, value]]});
  assert.equal(fixture.messages.length, 1);
  assert.equal(fixture.messages[0].name, 'trafficResponse');
  assert.equal(fixture.messages[0].payload.stage, 'mobileBalanceRendered');
  assert.deepEqual(JSON.parse(fixture.messages[0].payload.body),
    {source: 'officialRendered', balanceText: expected});
  assert.equal(fixture.messages[0].payload.url, fixture.context.location.href);
}
for (const tiles of [
  [['本月费用', '12.34元']], [['实时费用', '12.34元']], [['可用余额', '12.34元']],
  [['话费余额', '12.34']], [['话费余额', '12.34KB']], [['话费余额', '12.345元']],
  [['话费余额', '1 2.34 元']], [['话费余额', '1e3元']],
  [['话费余额', '12.34元 实时费用 1元']],
  [['话费余额', '12元'], ['账户余额', '13元']],
  [['话费余额', '12元', {style: {display: 'none'}}]],
  [['话费余额', '12元', {style: {visibility: 'hidden'}}]],
  [['话费余额', '12元', {style: {opacity: '0'}}]],
  [['话费余额', '12元', {hidden: true}]],
]) assert.equal(setup({tiles}).messages.length, 0, JSON.stringify(tiles));
for (const options of [
  {origin: 'https://wx.10086.cn.evil.test'}, {origin: 'http://wx.10086.cn'},
  {pathname: '/website/bind/bindAccount/new'}, {hash: '#/login'}, {subframe: true},
]) assert.equal(setup(options).messages.length, 0, JSON.stringify(options));

const delayed = setup({ready: false});
assert.equal(delayed.messages.length, 0);
delayed.ready();
assert.equal(delayed.messages.length, 1);
delayed.run();
assert.equal(delayed.messages.length, 2, 're-injection explicitly reads current DOM again');
delayed.setTiles([['话费余额', '0元']]);
delayed.mutation();
assert.equal(delayed.messages.length, 2, 'mutations are coalesced');
delayed.tick(300);
assert.equal(delayed.messages.length, 3, 'changed current balance is sent');
const absent = setup({tiles: []});
absent.tick(6100);
assert.equal(absent.timers.size, 0, 'scan deadline bounds polling');
assert.equal(absent.activeObservers(), 0, 'scan deadline disconnects observer');
absent.setTiles([['话费余额', '7元']]);
absent.mutation();
assert.equal(absent.messages.length, 0, 'no asynchronous scans after deadline');
absent.run();
assert.equal(absent.messages.length, 1, 'onLoadStop reads current DOM after initial deadline');
const changing = setup({tiles: []});
changing.context.location.pathname = '/website/bind/bindAccount/new';
changing.setTiles([['话费余额', '3元']]);
changing.mutation();
changing.tick(300);
assert.equal(changing.messages.length, 0, 'login navigation blocks a late balance');
assert.equal(changing.timers.size, 0);
console.log('PASS: mobile balance yuan/zero/debt, strict labels, page/frame/visibility guards, bounded current-DOM scans');
