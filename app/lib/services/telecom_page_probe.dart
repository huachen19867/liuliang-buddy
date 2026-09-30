/// Reads only rendered flow rows of the current official billing component.
/// The modal can be hidden with v-show; no click, login interception or request
/// signing is performed. Its displayed rounded values are estimates.
const telecomRenderedCaptureScript = r'''
(() => {
  'use strict';
  if (window.top !== window || location.origin !== 'https://e.dlife.cn' ||
      location.pathname !== '/portal/web/index.html') return;
  if (window.__liuliangTelecomProbe) return;
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
    if (!elements.length || elements.length > 200) return;
    const rows = [];
    for (const element of elements) {
      const balance = element.querySelector('.bill-balance[data-id]');
      if (!balance) return;
      const type = balance.getAttribute('data-id');
      if (!/^0*3$/.test(type || '')) continue;
      const name = (element.querySelector('.bill-title')?.textContent || '').trim();
      const text = (balance.textContent || '').replace(/\s+/g, ' ').trim();
      const match = /^已使用\s*(\d+(?:\.\d+)?\s*(?:GB|MB|KB|B))\s*\/\s*(\d+(?:\.\d+)?\s*(?:GB|MB|KB|B))$/i.exec(text);
      // A malformed flow row blocks the aggregate rather than silently dropping it.
      rows.push({name: name.slice(0, 200), used: match ? match[1] : null,
        total: match ? match[2] : null});
    }
    if (!rows.length) return;
    const body = JSON.stringify({source: 'officialRendered', rows});
    if (body !== previous) { pending = body; flush(); }
  };
  const schedule = () => {
    if (timer !== null) clearTimeout(timer);
    timer = setTimeout(scan, 300);
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
