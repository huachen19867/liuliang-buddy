/// Restores the existing E5 query initialization after the official header
/// stopped initializing its legacy session object. Invoke after page load for
/// a user-requested query, once per document. No credentials leave the page.
/// Bound the official session request asynchronously, preserving its callbacks
/// and authentication implementation. Never block the WebView on sync XHR.
const unicomOfficialQueryScript = r'''
(() => {
  'use strict';
  function startWhenReady() {
  if (window.top !== window ||
      location.origin !== 'https://iservice.10010.com' ||
      !['/e5/index.html', '/e5/query.html'].includes(location.pathname)) return;
  if (window.__liuliangUnicomOfficialQueryStarted ||
      window.__liuliangUnicomOfficialQueryPending) return;
  const session = window.myE3LoginObj;
  const query = window.E3QueryMain;
  const jq = window.jQuery;
  if (!session || typeof session.sendRequest !== 'function' ||
      !query || typeof query.loadData !== 'function' ||
      !window.query_info ||
      typeof window.query_info.personalInfo_back !== 'function' ||
      !jq || window.$ !== jq || typeof jq.ajax !== 'function') {
    // Some mobile WebViews finish navigation before deferred official scripts.
    // Wait only for those functions, never repeat authentication requests.
    const attempts = window.__liuliangUnicomReadinessAttempts || 0;
    if (attempts >= 16) return;
    window.__liuliangUnicomReadinessAttempts = attempts + 1;
    window.__liuliangUnicomOfficialQueryPending = true;
    setTimeout(() => {
      window.__liuliangUnicomOfficialQueryPending = false;
      startWhenReady();
    }, 500);
    return;
  }
  // Existing official initialization owns ready or partially populated state.
  // Never treat a stale true flag as a newly confirmed session.
  if (session.isLogin === true || session.userInfo != null) return;
  window.__liuliangUnicomOfficialQueryStarted = true;
  const originalAjax = jq.ajax;
  let intercepted = false;
  jq.ajax = function(settings) {
    // This wrapper exists only during the original sendRequest invocation.
    // Unexpected requests are not executed with its unsafe sync behavior.
    if (intercepted || !settings || typeof settings !== 'object') return;
    let url;
    try { url = new URL(settings.url, location.href); } catch (_) { return; }
    if (url.origin !== location.origin ||
        url.pathname !== '/e3/static/check/checklogin/' ||
        String(settings.type).toUpperCase() !== 'POST') return;
    intercepted = true;
    const success = settings.success;
    const bounded = Object.assign({}, settings, {async: true, timeout: 12000,
      success: function(data) {
        try {
          if (typeof success === 'function') success.apply(this, arguments);
          if (!data || data.isLogin !== true || session.isLogin !== true ||
              !session.userInfo ||
              !['01', '02', '11'].includes(session.userInfo.nettype) ||
              location.origin !== 'https://iservice.10010.com' ||
              !['/e5/index.html', '/e5/query.html'].includes(location.pathname)) return;
          query.loadData('/userinfoE5query', null,
            'query_info.personalInfo_back(data)');
        } catch (_) {}
      }
    });
    return originalAjax.call(this, bounded);
  };
  try {
    session.sendRequest();
  } catch (_) {
    // Preserve the official page and let existing query error handling finish.
  } finally {
    jq.ajax = originalAjax;
  }
  }
  startWhenReady();
})();
''';
