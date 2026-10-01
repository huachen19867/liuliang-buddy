const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname,
  '../../lib/services/unicom_official_query.dart'), 'utf8');
const script = source.split("const unicomOfficialQueryScript = r'''")[1]
  .split("''';")[0];
let scenarios = 0;
function setup(options = {}) {
  const calls = [];
  const session = {
    isLogin: false,
    userInfo: null,
    sendRequest() {
      calls.push('session');
      if (options.throws) throw new Error('official request failed');
      this.isLogin = options.login ?? false;
      this.userInfo = options.info ?? null;
      return options.returned ?? this.isLogin;
    },
  };
  const window = {
    myE3LoginObj: session,
    E3QueryMain: {loadData(...args) {calls.push(args);}},
    query_info: {personalInfo_back() {}},
  };
  window.top = options.iframe ? {} : window;
  const context = vm.createContext({window, location: {
    origin: options.origin ?? 'https://iservice.10010.com',
    pathname: options.pathname ?? '/e5/index.html',
  }});
  return {window, session, calls, run: () => vm.runInContext(script, context)};
}
function test(name, fn) {
  fn();
  scenarios++;
  console.log(`PASS ${name}`);
}

test('only exact secure E5 top frame', () => {
  for (const options of [
    {origin: 'http://iservice.10010.com'},
    {origin: 'https://iservice.10010.com:444'},
    {origin: 'https://www.10010.com'},
    {origin: 'https://iservice.10010.com.attacker.test'},
    {pathname: '/e5/login.html'}, {pathname: '/e5/index.html/extra'},
    {iframe: true},
  ]) {
    const t = setup(options); t.run(); assert.deepEqual(t.calls, []);
  }
});
test('missing official objects and functions do nothing', () => {
  for (const mutate of [
    t => delete t.window.myE3LoginObj,
    t => delete t.session.sendRequest,
    t => delete t.window.E3QueryMain,
    t => delete t.window.E3QueryMain.loadData,
    t => delete t.window.query_info,
    t => delete t.window.query_info.personalInfo_back,
  ]) {
    const t = setup(); mutate(t); t.run(); assert.deepEqual(t.calls, []);
    assert.equal(t.window.__liuliangUnicomOfficialQueryStarted, undefined);
  }
});
test('ready and partially populated state belongs to original page', () => {
  for (const state of [
    {isLogin: true, userInfo: {nettype: '11'}},
    {isLogin: true, userInfo: null},
    {isLogin: false, userInfo: {nettype: '11'}},
  ]) {
    const t = setup(); Object.assign(t.session, state); t.run();
    assert.deepEqual(t.calls, []);
  }
});
test('anonymous session checked once without balance request', () => {
  const t = setup(); t.run(); t.run();
  assert.deepEqual(t.calls, ['session']);
});
test('official exception does not escape or repeat', () => {
  const t = setup({throws: true}); t.run(); t.run();
  assert.deepEqual(t.calls, ['session']);
});
test('confirmed mobile types use exact official query once', () => {
  for (const nettype of ['01', '02', '11']) {
    for (const pathname of ['/e5/index.html', '/e5/query.html']) {
      const t = setup({login: true, info: {nettype}, pathname});
      t.run(); t.run();
      assert.deepEqual(t.calls, ['session', ['/userinfoE5query', null,
        'query_info.personalInfo_back(data)']]);
    }
  }
});
test('strict confirmation and network type gate', () => {
  for (const options of [
    {login: 'true', info: {nettype: '11'}},
    {login: true, returned: 'true', info: {nettype: '11'}},
    {login: true, returned: false, info: {nettype: '11'}},
    {login: true},
    ...['', '1', '01,02,11', '03', 11, null, undefined].map(nettype =>
      ({login: true, info: {nettype}})),
  ]) {
    const t = setup(options); t.run(); assert.deepEqual(t.calls, ['session']);
  }
});
test('balance callback exception remains bounded', () => {
  const t = setup({login: true, info: {nettype: '11'}});
  let count = 0;
  t.window.E3QueryMain.loadData = () => {count++; throw new Error('official');};
  t.run(); t.run(); assert.equal(count, 1);
});
console.log(`${scenarios} official Unicom query scenarios passed (synthetic).`);
