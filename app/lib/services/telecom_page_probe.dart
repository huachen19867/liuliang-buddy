/// Reads rendered package rows of the current official billing component.
/// The modal can be hidden with v-show; no click, login interception or request
/// signing is performed. Its displayed rounded values are estimates.
const telecomRenderedCaptureScript = r'''
(() => {
  'use strict';
  if (window.top !== window || location.origin !== 'https://e.dlife.cn' ||
      location.pathname !== '/portal/web/index.html') return;
  if (window.__liuliangTelecomProbe) {
    // Explicit native query/load completion may arrive after an early bridge
    // message was ignored. Re-read current DOM, never replay cached rows.
    if (typeof window.__liuliangTelecomRescan === 'function')
      window.__liuliangTelecomRescan();
    return;
  }
  window.__liuliangTelecomProbe = true;
  let previous = '', pending = null, timer = null;
  const flush = () => {
    const bridge = window.flutter_inappwebview;
    if (!pending || !bridge || typeof bridge.callHandler !== 'function') return;
    try {
      const body = pending;
      Promise.resolve(bridge.callHandler('trafficResponse', {
        url: location.href, pageUrl: location.href, stage: 'telecomRendered',
        body, status: 200
      })).catch(() => {});
      previous = body; pending = null;
    } catch (_) {}
  };
  const scan = () => {
    timer = null;
    if (!['', '#/'].includes(location.hash)) { pending = null; return; }
    const elements = document.querySelectorAll('#balanceModal .bill-list > .list');
    // Do not turn a truncated package list into a total.
    if (!elements.length || elements.length > 200) { pending = null; return; }
    const rows = [], allowanceRows = [];
    for (const element of elements) {
      const balance = element.querySelector('.bill-balance[data-id]');
      if (!balance) { pending = null; return; }
      const type = balance.getAttribute('data-id');
      const name = (element.querySelector('.bill-title')?.textContent || '').trim();
      const text = (balance.textContent || '').replace(/\s+/g, ' ').trim();
      if (/^0*[12]$/.test(type || '')) {
        const kind = /^0*1$/.test(type) ? 'voice' : 'sms';
        if (kind === 'sms' && !/短信|短、彩信|短彩信/.test(name)) continue;
        const service = /^已使用\s*(\d+(?:\.\d+)?\s*(?:分钟|分|条|次))\s*\/\s*(\d+(?:\.\d+)?\s*(?:分钟|分|条|次)|不限量|无限量|无限|不限|不限制)$/i.exec(text);
        allowanceRows.push({kind, name: name.slice(0, 200),
          used: service ? service[1] : null, total: service ? service[2] : null});
        continue;
      }
      if (!/^0*3$/.test(type || '')) continue;
      const match = /^已使用\s*(\d+(?:\.\d+)?\s*(?:GB|MB|KB|B))\s*\/\s*(\d+(?:\.\d+)?\s*(?:GB|MB|KB|B)|(?:不限量|无限量|无限|不限|不限制|unlimited|no\s*limit)\s*(?:GB|MB|KB|B)?)$/i.exec(text);
      // A malformed flow row blocks the aggregate rather than silently dropping it.
      rows.push({name: name.slice(0, 200), used: match ? match[1] : null,
        total: match ? match[2] : null});
    }
    if (!rows.length && !allowanceRows.length) { pending = null; return; }
    const money = document.querySelector('#balanceModal #mobileBalance');
    const moneyText = (money?.textContent || '').replace(/\s+/g, '').trim();
    // The exact official modal labels this value as 余额 and its unit as 元.
    // Never interpret mobileTimeBalance (current charges) as account balance.
    const moneyParent = (money?.parentElement?.textContent || '').replace(/\s+/g, '');
    const following = (money?.parentElement?.nextSibling?.textContent || '').trim();
    const balanceText = /^-?\d+(?:\.\d{1,2})?$/.test(moneyText) &&
      moneyParent.startsWith('余额:') && /^元(?:\s|$)/.test(following)
      ? moneyText + ' 元' : null;
    const payload = {source: 'officialRendered', rows, allowanceRows};
    if (balanceText !== null) payload.balanceText = balanceText;
    const body = JSON.stringify(payload);
    if (body !== previous) { pending = body; flush(); }
  };
  const schedule = () => {
    // Continuous unrelated page mutations must not postpone scanning forever.
    if (timer !== null) return;
    timer = setTimeout(scan, 300);
  };
  window.__liuliangTelecomRescan = () => {
    previous = ''; pending = null;
    scan();
  };
  window.addEventListener('flutterInAppWebViewPlatformReady', () => { scan(); flush(); });
  window.addEventListener('hashchange', schedule);
  const start = () => {
    if (!document.body) return;
    new MutationObserver(schedule).observe(document.body, {childList: true, subtree: true, characterData: true});
    schedule();
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
})();
''';
