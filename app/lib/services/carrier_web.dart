import '../data/models.dart';
import 'page_probe.dart';

String carrierLoginUrl(Carrier carrier) => switch (carrier) {
  Carrier.mobile => mobileLoginUrl,
  Carrier.broadnet => broadnetLoginUrl,
  Carrier.unicom => unicomLoginUrl,
  Carrier.telecom => 'https://e.dlife.cn/portal/web/index.html#/login',
};

String carrierQueryUrl(Carrier carrier) => switch (carrier) {
  Carrier.mobile => mobileQueryUrl,
  Carrier.broadnet => broadnetQueryUrl,
  Carrier.unicom => unicomQueryUrl,
  Carrier.telecom => 'https://e.dlife.cn/portal/web/index.html#/',
};

bool isCarrierLoginPage(Uri uri) =>
    uri.path.toLowerCase().contains('login') ||
    uri.path.contains('bindAccount') ||
    uri.fragment.toLowerCase().contains('/login');

bool isCarrierNavigationAllowed(Carrier carrier, Uri uri) {
  if (uri.toString() == 'about:blank') return true;
  if (!_https(uri)) return false;
  final base = switch (carrier) {
    Carrier.mobile => '10086.cn',
    Carrier.broadnet => '10099.com.cn',
    Carrier.unicom => '10010.com',
    Carrier.telecom => '189.cn',
  };
  return uri.host == base ||
      uri.host.endsWith('.$base') ||
      (carrier == Carrier.telecom && uri.host == 'e.dlife.cn');
}

/// New carriers use exact official query pages and response identities.
bool isCarrierResponseAllowed(
  Carrier carrier,
  Uri? url,
  Uri? page,
  String? stage,
) {
  if (url == null || page == null || !_https(url) || !_https(page)) {
    return false;
  }
  return switch (carrier) {
    Carrier.mobile =>
      page.host == 'wx.10086.cn' &&
          url.host == page.host &&
          url.path.contains('getNewMarginInfo'),
    Carrier.broadnet =>
      page.host == 'www.10099.com.cn' &&
          (url.host == 'www.10099.com.cn' || url.host == 'wx.10099.com.cn') &&
          url.path.contains('qryUserRes'),
    Carrier.unicom =>
      page.host == 'iservice.10010.com' &&
          ['/e5/index.html', '/e5/query.html'].contains(page.path) &&
          url.host == page.host &&
          url.path == '/e3/static/query/userinfoE5query',
    Carrier.telecom =>
      stage == 'telecomRendered' &&
          page.host == 'e.dlife.cn' &&
          page.path == '/portal/web/index.html' &&
          ['', '/'].contains(page.fragment) &&
          url == page,
  };
}

bool _https(Uri uri) =>
    uri.scheme == 'https' && uri.userInfo.isEmpty && uri.port == 443;
