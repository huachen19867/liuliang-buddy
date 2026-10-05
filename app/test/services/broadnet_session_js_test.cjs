// Run: node test/services/broadnet_session_js_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const source = fs.readFileSync(path.join(__dirname,
  '../../lib/services/page_probe.dart'), 'utf8');
const capture = source.match(/const broadnetSessionCaptureScript = r'''([\s\S]*?)''';/)[1];
// Execute the actual generated JS template; Dart payload encoding is separately
// covered by page_probe_test.dart, including quotes and interpolation characters.
const restoreTemplate = source.slice(source.indexOf('String broadnetSessionRestoreScript'))
  .match(/return '''([\s\S]*?)''';/)[1];
const saved = {phoneInfo: 'opaque-official-phone', sessionId: 'opaque-official-session'};
const restore = restoreTemplate.replace('$payload', JSON.stringify(saved));
const phoneKey = 'broadnetUserPhoneInfo';
const sessionKey = 'broadnetUserSessionId';

function setup({origin = 'https://www.10099.com.cn',
  pathname = '/personal-center-number-order.html', subframe = false,
  entries = {}, storageError = false} = {}) {
  const values = new Map(Object.entries(entries));
  const writes = [];
  const context = {
    location: {origin, pathname},
    sessionStorage: {
      getItem(key) { if (storageError) throw Error('unavailable'); return values.get(key) ?? null; },
      setItem(key, value) { if (storageError) throw Error('unavailable'); writes.push([key, value]); values.set(key, value); },
    },
  };
  context.window = context;
  context.top = subframe ? {} : context;
  return {values, writes, run(script) { return vm.runInNewContext(script, context); }};
}

const empty = setup();
assert.equal(empty.run(restore), true);
assert.deepEqual(Object.fromEntries(empty.values), {[phoneKey]: saved.phoneInfo, [sessionKey]: saved.sessionId});
assert.deepEqual(JSON.parse(JSON.stringify(empty.run(capture))), saved);
assert.equal(empty.run(restore), false, 'second restore must preserve official page storage');

const current = setup({entries: {[phoneKey]: 'new-phone', [sessionKey]: 'new-session'}});
assert.equal(current.run(restore), false);
assert.equal(current.writes.length, 0, 'new login is never replaced with the saved backup');
for (const entries of [{[phoneKey]: 'new-phone'}, {[sessionKey]: 'new-session'}]) {
  const partial = setup({entries});
  assert.equal(partial.run(capture), null);
  assert.equal(partial.run(restore), true);
  assert.deepEqual(Object.fromEntries(partial.values), {[phoneKey]: saved.phoneInfo, [sessionKey]: saved.sessionId},
    'replace an incomplete pair together; guest sessionId alone must not block recovery');
}
for (const options of [{origin: 'https://www.10099.com.cn.evil.test'},
  {pathname: '/login.html'}, {subframe: true}, {storageError: true}]) {
  const rejected = setup(options);
  assert.equal(rejected.run(restore), false);
  assert.equal(rejected.run(capture), null);
  assert.equal(rejected.writes.length, 0);
}
for (const entries of [
  {[phoneKey]: ' ', [sessionKey]: saved.sessionId},
  {[phoneKey]: saved.phoneInfo, [sessionKey]: ' '},
  {[phoneKey]: 'x'.repeat(20001), [sessionKey]: saved.sessionId},
  {[phoneKey]: saved.phoneInfo, [sessionKey]: 'x'.repeat(20001)},
]) assert.equal(setup({entries}).run(capture), null);
const exact = {[phoneKey]: 'x'.repeat(20000), [sessionKey]: 'y'.repeat(20000)};
assert.equal(setup({entries: exact}).run(capture).sessionId, exact[sessionKey]);
console.log('Broadnet session JS: restoration, fresh-login protection, origin guards and bounds passed');
