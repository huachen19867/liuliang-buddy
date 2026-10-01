/// Restores the existing E5 query initialization after the official header
/// stopped initializing its legacy session object. Invoke after page load for
/// a user-requested query, once per document. No credentials leave the page.
/// The official session function uses synchronous XHR without a timeout;
/// retain its behavior rather than reimplementing its authentication request.
const unicomOfficialQueryScript = r'''
(() => {
  'use strict';
  if (window.top !== window ||
      location.origin !== 'https://iservice.10010.com' ||
      !['/e5/index.html', '/e5/query.html'].includes(location.pathname)) return;
  if (window.__liuliangUnicomOfficialQueryStarted) return;
  const session = window.myE3LoginObj;
  const query = window.E3QueryMain;
  if (!session || typeof session.sendRequest !== 'function' ||
      !query || typeof query.loadData !== 'function' ||
      !window.query_info ||
      typeof window.query_info.personalInfo_back !== 'function') return;
  // Existing official initialization owns ready or partially populated state.
  // Never treat a stale true flag as a newly confirmed session.
  if (session.isLogin === true || session.userInfo != null) return;
  window.__liuliangUnicomOfficialQueryStarted = true;
  try {
    const confirmed = session.sendRequest();
    if (confirmed !== true || session.isLogin !== true ||
        !session.userInfo ||
        !['01', '02', '11'].includes(session.userInfo.nettype)) return;
    query.loadData('/userinfoE5query', null,
      'query_info.personalInfo_back(data)');
  } catch (_) {
    // Preserve the official page and let existing query error handling finish.
  }
})();
''';
