import 'dart:convert';

import 'package:encrypt/encrypt.dart' as crypto;

const mobileLoginUrl = 'https://wx.10086.cn/website/bind/bindAccount/new';
const mobileQueryUrl = 'https://wx.10086.cn/website/spa/main/newHome';
const broadnetLoginUrl = 'https://www.10099.com.cn/login.html';
const broadnetQueryUrl =
    'https://www.10099.com.cn/personal-center-number-order.html';
const unicomQueryUrl = 'https://iservice.10010.com/e5/index.html';
const unicomLoginUrl =
    'https://uac.10010.com/portal/mallLogin.jsp?redirectURL=https://iservice.10010.com/e5/index.html';

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
        url.pathname === '/e3/static/query/userinfoE5query');
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
      const payload = {url: new URL(url, location.href).href,
        body, status, stage, pageUrl: location.href};
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
    if (!phoneInfo || !sessionId || phoneInfo.length > 20000 ||
        sessionId.length > 20000) return null;
    return {phoneInfo, sessionId};
  } catch (_) { return null; }
})();
''';

String broadnetSessionRestoreScript(Map<String, dynamic>? saved) {
  final phoneInfo = saved?['phoneInfo'];
  final sessionId = saved?['sessionId'];
  if (phoneInfo is! String ||
      sessionId is! String ||
      phoneInfo.isEmpty ||
      sessionId.isEmpty ||
      phoneInfo.length > 20000 ||
      sessionId.length > 20000) {
    return '(() => false)();';
  }
  // JSON encoding preserves literal values and prevents script interpolation.
  final payload = jsonEncode({'phoneInfo': phoneInfo, 'sessionId': sessionId});
  return '''
(() => {
  if (location.origin !== 'https://www.10099.com.cn' || window.top !== window)
    return false;
  if (location.pathname === '/login.html') return false;
  try {
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
