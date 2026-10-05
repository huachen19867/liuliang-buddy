import 'dart:convert';

import 'package:encrypt/encrypt.dart' as crypto;

import 'broadnet_session.dart';

const mobileLoginUrl = 'https://wx.10086.cn/website/bind/bindAccount/new';
const mobileQueryUrl = 'https://wx.10086.cn/website/spa/main/newHome';
const broadnetLoginUrl = 'https://www.10099.com.cn/login.html';
const broadnetQueryUrl =
    'https://www.10099.com.cn/personal-center-number-order.html';
const unicomQueryUrl = 'https://iservice.10010.com/e5/index.html';
const unicomLoginUrl =
    'https://uac.10010.com/portal/mallLogin.jsp?redirectURL=https://iservice.10010.com/e5/index.html';

/// Reads only a visible labelled balance on the current official homepage.
/// It does not issue requests or infer currency from unlabelled fee fields.
/// A second injection reads the current DOM and restarts the bounded scan.
const mobileBalanceCaptureScript = r'''
(() => {
  'use strict';
  const onHome = () => window.top === window &&
    location.origin === 'https://wx.10086.cn' &&
    location.pathname === '/website/spa/main/newHome' &&
    !/login/i.test(location.hash || '');
  if (!onHome()) return;
  if (window.__liuliangMobileBalanceProbe) {
    window.__liuliangMobileBalanceProbe.restart();
    return;
  }
  const labels = new Set(['话费余额', '账户余额']);
  const normalize = text => String(text || '').replace(/\s+/g, '');
  const visible = node => {
    if (!node || node.nodeType !== 1 || !node.getClientRects().length) return false;
    for (let parent = node; parent; parent = parent.parentElement) {
      const style = getComputedStyle(parent);
      if (style.display === 'none' || style.visibility === 'hidden' ||
          style.visibility === 'collapse' || style.opacity === '0' || parent.hidden ||
          parent.getAttribute('aria-hidden') === 'true') return false;
    }
    return true;
  };
  let timer, observer, deadline;
  let lastSent = '';
  let dirty = false;
  const stop = () => {
    clearInterval(timer);
    if (observer) observer.disconnect();
    observer = null;
  };
  const scan = () => {
    if (!onHome()) { stop(); return; }
    if (Date.now() > deadline) { stop(); return; }
    const values = new Set();
    const nodes = document.querySelectorAll('body *');
    // Bound work on unexpectedly large pages rather than scanning forever.
    if (nodes.length > 10000) return;
    for (const label of nodes) {
      if (!labels.has(normalize(label.textContent)) || !visible(label)) continue;
      // Support a tile with nested or separately rendered amount/unit.
      // Its complete visible text must contain only the label and yuan amount.
      let parent = label.parentElement;
      for (let depth = 0; parent && depth < 3; depth++, parent = parent.parentElement) {
        if (!visible(parent)) continue;
        const text = String(parent.innerText || '').trim();
        const match = /^(?:话费余额|账户余额)\s*(-?\d+(?:\.\d{1,2})?)\s*元$/.exec(text) ||
          /^(-?\d+(?:\.\d{1,2})?)\s*元\s*(?:话费余额|账户余额)$/.exec(text);
        if (match) values.add(match[1] + '元');
      }
    }
    // Conflicting labelled tiles are not sufficient evidence for one balance.
    if (values.size !== 1) return;
    const text = values.values().next().value;
    if (text === lastSent) return;
    const bridge = window.flutter_inappwebview;
    if (!bridge || typeof bridge.callHandler !== 'function') return;
    try {
      Promise.resolve(bridge.callHandler('trafficResponse', {
        url: location.href, pageUrl: location.href, status: 200,
        stage: 'mobileBalanceRendered',
        body: JSON.stringify({source: 'officialRendered', balanceText: text})
      })).catch(() => {});
      lastSent = text;
    } catch (_) {}
  };
  const restart = () => {
    stop();
    // Early bridge events can arrive before a native query begins. A new
    // injection explicitly requests the current DOM, never stored old text.
    lastSent = '';
    dirty = false;
    deadline = Date.now() + 6000;
    scan();
    if (!onHome()) return;
    const observe = () => {
      if (!observer && document.documentElement) {
        // Document-start can precede the first element. Attach when it exists.
        // Coalesce changes to at most one full DOM scan per 300ms.
        observer = new MutationObserver(() => { dirty = true; });
        observer.observe(document.documentElement, {childList: true,
          subtree: true, characterData: true, attributes: true,
          attributeFilter: ['class', 'style', 'hidden', 'aria-hidden']});
      }
    };
    observe();
    timer = setInterval(() => {
      if (!observer) { observe(); dirty = true; }
      if (dirty || Date.now() > deadline) { dirty = false; scan(); }
    }, 300);
  };
  window.__liuliangMobileBalanceProbe = {restart};
  window.addEventListener('flutterInAppWebViewPlatformReady', scan);
  restart();
})();
''';

/// Decodes transport JSON only; the carrier parser validates business fields.
Map<String, dynamic>? decodeMobileResponse(String raw) {
  var text = raw.trim();
  if (text.isEmpty || text.length > 2 * 1024 * 1024) return null;
  try {
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(text)) {
      // AES ciphertext must contain complete 16-byte blocks.
      if (text.length % 32 != 0) return null;
      final encrypter = crypto.Encrypter(
        crypto.AES(
          crypto.Key.fromUtf8('1234123412ABCDEF'),
          mode: crypto.AESMode.cbc,
          padding: 'PKCS7',
        ),
      );
      text = encrypter.decrypt(
        crypto.Encrypted.fromBase16(text),
        iv: crypto.IV.fromUtf8('ABCDEF1234123412'),
      );
    }
    final value = jsonDecode(text);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}

/// Inject at document start in the main frame only. Copies selected responses;
/// official requests, response objects, form actions and consent stay intact.
const responseCaptureScript = r'''
(() => {
  'use strict';
  const allowed = ['https://wx.10086.cn', 'https://www.10099.com.cn',
    'https://iservice.10010.com'];
  if (window.top !== window || !allowed.includes(location.origin)) return;
  if (window.__liuliangResponseProbe) return;
  window.__liuliangResponseProbe = true;
  const selected = (raw) => {
    try {
      const url = new URL(raw, location.href);
      return (location.origin === 'https://wx.10086.cn' &&
        url.origin === 'https://wx.10086.cn' &&
        url.pathname.includes('getNewMarginInfo')) ||
        (location.origin === 'https://www.10099.com.cn' &&
        ['https://www.10099.com.cn', 'https://wx.10099.com.cn'].includes(url.origin) &&
        url.pathname.includes('qryUserRes')) ||
        (location.origin === 'https://iservice.10010.com' &&
        ['/e5/index.html', '/e5/query.html'].includes(location.pathname) &&
        url.origin === 'https://iservice.10010.com' &&
        ['/e3/static/query/userinfoE5query',
          '/e3/static/check/checklogin/'].includes(url.pathname));
    } catch (_) { return false; }
  };
  const pendingMessages = [];
  const deliver = payload => {
    try {
      const bridge = window.flutter_inappwebview;
      if (!bridge || typeof bridge.callHandler !== 'function') return false;
      Promise.resolve(bridge.callHandler('trafficResponse', payload)).catch(() => {});
      return true;
    } catch (_) { return false; }
  };
  const flush = () => {
    while (pendingMessages.length && deliver(pendingMessages[0])) {
      pendingMessages.shift();
    }
  };
  window.addEventListener('flutterInAppWebViewPlatformReady', flush);
  const send = (url, body, status, stage = 'raw') => {
    try {
      if (!selected(url) || typeof body !== 'string' ||
          body.length > 2097152) return;
      const responseUrl = new URL(url, location.href);
      if (location.origin === 'https://iservice.10010.com' &&
          responseUrl.pathname === '/e3/static/check/checklogin/') {
        // E5 can stay on its home page while logged out and never request
        // balances. Forward only a confirmed negative session flag; never
        // bridge the checklogin profile, identifiers, or query parameters.
        if (status < 200 || status >= 300) return;
        const session = JSON.parse(body);
        if (!session || session.isLogin !== false) return;
        body = '{"isLogin":false}';
        stage = 'unicomSession';
        responseUrl.search = '';
        responseUrl.hash = '';
      }
      const payload = {url: responseUrl.href,
        body, status, stage, pageUrl: stage === 'unicomSession'
          ? location.origin + location.pathname : location.href};
      flush();
      if (!deliver(payload)) {
        // Keep a small, bounded queue for document-start responses before the
        // native WebView bridge exists. Nothing persists beyond this page.
        while (pendingMessages.length >= 8) pendingMessages.shift();
        pendingMessages.push(payload);
      }
    } catch (_) {}
  };
  // The business site uses a private webpack jQuery instance. window.jQuery
  // belongs to the WAF and never receives the business ajaxSuccess events.
  // Observe the official decoded result without rerunning its dataFilter.
  if (location.origin === 'https://www.10099.com.cn') {
    const attached = new WeakSet();
    const wrappedJsonp = new WeakSet();
    let attempts = 0;
    const attach = jq => {
      if (typeof jq !== 'function' || !jq.fn || !jq.fn.on) return false;
      if (attached.has(jq)) return true;
      try {
        jq(document).on('ajaxSuccess.liuliang', (event, xhr, settings, data) => {
          try {
            if (!settings || !selected(settings.url)) return;
            const value = xhr.responseJSON === undefined ? data : xhr.responseJSON;
            if (!value || typeof value !== 'object' || Array.isArray(value)) return;
            send(settings.url, JSON.stringify(value), xhr.status, 'officialDecoded');
          } catch (_) {}
        });
        attached.add(jq);
        return true;
      } catch (_) { return false; }
    };
    const observeWebpack = () => {
      const jsonp = window.webpackJsonp;
      if (typeof jsonp !== 'function' || wrappedJsonp.has(jsonp)) return;
      const observer = function(chunkIds, modules) {
        // Official vendor-21074.js exports business jQuery as module 0.
        // Wrap its factory only when the website registers it; do not force
        // initialization or execute additional website requests.
        const factory = modules && modules[0];
        if (typeof factory === 'function') {
          modules[0] = function(module) {
            const result = factory.apply(this, arguments);
            attach(module && module.exports);
            return result;
          };
        }
        return jsonp.apply(this, arguments);
      };
      wrappedJsonp.add(observer);
      window.webpackJsonp = observer;
    };
    const discover = () => {
      observeWebpack();
      attach(window.jQuery);
      attach(window.$);
      flush();
    };
    const onScriptLoad = event => {
      if (event.target && event.target.tagName === 'SCRIPT') discover();
    };
    document.addEventListener('load', onScriptLoad, true);
    discover();
    const timer = setInterval(() => {
      discover();
      if (++attempts >= 100) {
        clearInterval(timer);
      }
    }, 100);
  }
  const urls = new WeakMap();
  const open = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    const result = open.apply(this, arguments);
    urls.set(this, String(url));
    return result;
  };
  const xhrSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function() {
    const requestUrl = urls.get(this);
    if (selected(requestUrl)) {
      this.addEventListener('load', () => {
        try {
          const url = this.responseURL || requestUrl;
          if (this.responseType === '' || this.responseType === 'text') {
            send(url, this.responseText, this.status);
          } else if (this.responseType === 'json') {
            send(url, JSON.stringify(this.response), this.status);
          }
        } catch (_) {}
      }, { once: true });
    }
    return xhrSend.apply(this, arguments);
  };
  const originalFetch = window.fetch;
  if (typeof originalFetch === 'function') {
    window.fetch = function() {
      const pending = originalFetch.apply(this, arguments);
      pending.then(response => {
        try {
          if (selected(response.url)) {
            response.clone().text().then(body => {
              send(response.url, body, response.status);
            }).catch(() => {});
          }
        } catch (_) {}
      }).catch(() => {});
      return pending;
    };
  }
})();
''';

const broadnetSessionCaptureScript = r'''
(() => {
  if (location.origin !== 'https://www.10099.com.cn' || window.top !== window)
    return null;
  if (location.pathname === '/login.html') return null;
  try {
    const phoneInfo = sessionStorage.getItem('broadnetUserPhoneInfo');
    const sessionId = sessionStorage.getItem('broadnetUserSessionId');
    if (!phoneInfo || !sessionId || !phoneInfo.trim() || !sessionId.trim() ||
        phoneInfo.length > 20000 ||
        sessionId.length > 20000) return null;
    return {phoneInfo, sessionId};
  } catch (_) { return null; }
})();
''';

String broadnetSessionRestoreScript(Map<String, dynamic>? saved) {
  final session = normalizeBroadnetSession(saved);
  if (session == null) return '(() => false)();';
  // JSON encoding preserves literal values and prevents script interpolation.
  final payload = jsonEncode({
    'phoneInfo': session['phoneInfo'],
    'sessionId': session['sessionId'],
  });
  return '''
(() => {
  if (location.origin !== 'https://www.10099.com.cn' || window.top !== window)
    return false;
  if (location.pathname === '/login.html') return false;
  try {
    // Preserve a complete newer login. The website may create a guest
    // sessionId without phoneInfo; that alone must not block paired recovery.
    if (sessionStorage.getItem('broadnetUserPhoneInfo') &&
        sessionStorage.getItem('broadnetUserSessionId')) return false;
    const saved = $payload;
    sessionStorage.setItem('broadnetUserPhoneInfo', saved.phoneInfo);
    sessionStorage.setItem('broadnetUserSessionId', saved.sessionId);
    return true;
  } catch (_) { return false; }
})();
''';
}
