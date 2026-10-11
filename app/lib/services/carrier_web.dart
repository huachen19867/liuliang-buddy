import '../data/models.dart';
import 'page_probe.dart';

const mobileLoginHelpMessage =
    '支持时官网会显示本机号码的一键登录授权框。请使用要查询的移动卡的数据网络，核对官网显示的号码后自行同意协议；双卡手机的默认数据卡可能是另一个号码。未出现授权框或取号失败时，仍可用短信验证。\n\n可在官网自行勾选「3天免登录」。这个期限由移动官网控制，查询流量不保证续期，到期后仍需官网验证。\n\n如果网页不提供短信验证，或要求人脸验证，请先在中国移动官方 App 完成身份验证。官方 App 的验证不会自动同步本 App 的网页登录；网页版仍无法登录时，这个号码暂不支持自动查询。官方 App 下载入口：https://www.10086.cn/cmccclient/';

const mobileLoginGuide =
    '支持时官网会弹出本机号码授权框，请使用该号码的移动数据并核对号码；未出现时也可短信验证。完成后点「查询流量」。';

const mobileLoginHelp =
    '官网授权框弹出时，本 App 顶部会同时显示框内掩码号码，请自行核对后操作；本 App 不会替您勾选协议或点「一键登录」。官方授权框也提示：请勿连接热点登录，并确认该号码为您本机号码。\n\n$mobileLoginHelpMessage';

const broadnetLoginGuide =
    '请输入该卡手机号并按官网提示完成短信验证，再点「查询流量」。官网会话较短，到期会再次要求验证。';

const broadnetLoginHelpMessage =
    '广电官网登录需要短信验证码。中国广电官方 App 的「本机登录」由其自有认证服务提供，目前未向第三方应用开放接入，因此本 App 不提供免验证码按钮，也不会冒充官方认证。\n\n'
    '登录成功后，本机会在安全存储备份官网会话，重新打开页面时先尝试恢复；官网拒绝该会话时必须重新验证。备份不延长官网会话有效期，有用户反馈约三天后官网会再次要求验证。\n\n'
    '如果官网要求人脸验证或提示异常，请按官网提示在官方渠道处理后再回到本页。';

/// Outcome of comparing the official popup mask with the account's number.
enum MobileOneKeyMatch { match, mismatch, unknown }

/// The official one-key popup shows a masked number such as `138****1234`.
/// Only the revealed prefix and suffix digits are compared; hidden digits are
/// never guessed, so a partial overlap cannot report a match.
MobileOneKeyMatch compareMobileOneKeyMask(String? phone, String masked) {
  var normalizedPhone = (phone ?? '').trim();
  if (normalizedPhone.startsWith('+')) {
    normalizedPhone = normalizedPhone.substring(1);
  }
  final normalizedMask = masked.trim().replaceAll(RegExp(r'\s+'), '');
  if (normalizedPhone.isEmpty ||
      normalizedMask.isEmpty ||
      normalizedMask.length > 32 ||
      !RegExp(r'^[0-9*]+$').hasMatch(normalizedMask)) {
    return MobileOneKeyMatch.unknown;
  }
  final parts = normalizedMask.split('*');
  final prefix = parts.first;
  final suffix = parts.last;
  if (prefix.isEmpty && suffix.isEmpty) {
    return MobileOneKeyMatch.unknown;
  }
  if (parts.length == 1) {
    // Without hidden digits only an exact full-number display is comparable.
    return normalizedPhone == normalizedMask
        ? MobileOneKeyMatch.match
        : MobileOneKeyMatch.mismatch;
  }
  if (normalizedPhone.length <= prefix.length + suffix.length) {
    // A real mask always hides digits; a number that short cannot be it.
    return MobileOneKeyMatch.mismatch;
  }
  return normalizedPhone.startsWith(prefix) && normalizedPhone.endsWith(suffix)
      ? MobileOneKeyMatch.match
      : MobileOneKeyMatch.mismatch;
}

/// App-side guidance while the official one-key popup is visible. The popup
/// itself remains the only place where the user agrees or cancels.
String mobileOneKeyGuidance(MobileOneKeyMatch match, String masked) =>
    switch (match) {
      MobileOneKeyMatch.match =>
        '官网已弹出本机号码授权框（$masked），与该账号一致。请自行勾选协议后点官网的「一键登录」。未勾选「3天免登录」时，官网到期会再次验证。',
      MobileOneKeyMatch.mismatch =>
        '官网授权框显示 $masked，与该账号登记的号码不一致。请点官网的「暂不使用」，改用短信验证，或先在本 App 账号设置里更正号码。',
      MobileOneKeyMatch.unknown =>
        '官网已弹出本机号码授权框（$masked）。请核对它是当前账号的号码，再自行勾选协议并点「一键登录」；不一致请点「暂不使用」改用短信验证。',
    };

/// Read-only official number-authentication agreement, opened separately so
/// reading it never replaces the account's login page or triggers a query.
bool isMobileNumberAuthAgreement(Uri uri) =>
    _https(uri) &&
    uri.host == 'wap.cmpassport.com' &&
    uri.path == '/resources/html/contract.html' &&
    !uri.hasQuery;

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
          page.path == Uri.parse(mobileQueryUrl).path &&
          !isCarrierLoginPage(page) &&
          url.host == page.host &&
          ((stage == 'raw' && url.path.contains('getNewMarginInfo')) ||
              (stage == 'mobileBalanceRendered' && url == page)),
    Carrier.broadnet =>
      page.host == 'www.10099.com.cn' &&
          (url.host == 'www.10099.com.cn' || url.host == 'wx.10099.com.cn') &&
          url.path.contains('qryUserRes'),
    Carrier.unicom =>
      page.host == 'iservice.10010.com' &&
          ['/e5/index.html', '/e5/query.html'].contains(page.path) &&
          url.host == page.host &&
          ((stage == 'raw' && url.path == '/e3/static/query/userinfoE5query') ||
              (stage == 'unicomSession' &&
                  url.path == '/e3/static/check/checklogin/' &&
                  !url.hasQuery &&
                  !url.hasFragment)),
    Carrier.telecom =>
      stage == 'telecomRendered' &&
          page.host == 'e.dlife.cn' &&
          page.path == '/portal/web/index.html' &&
          ['', '/'].contains(page.fragment) &&
          url == page,
  };
}

/// A response may finish after an official page changes its query or fragment.
/// Keep only requests whose WebView is still on that carrier's balance page.
/// Telecom uses its hash as the actual route, so it requires exact equality.
bool isCarrierResponsePageCurrent(
  Carrier carrier,
  Uri capturedPage,
  Uri currentPage,
) {
  if (!_https(capturedPage) ||
      !_https(currentPage) ||
      isCarrierLoginPage(capturedPage) ||
      isCarrierLoginPage(currentPage)) {
    return false;
  }
  return switch (carrier) {
    Carrier.mobile =>
      capturedPage.host == 'wx.10086.cn' &&
          capturedPage.path == Uri.parse(mobileQueryUrl).path &&
          currentPage.host == 'wx.10086.cn' &&
          currentPage.path == Uri.parse(mobileQueryUrl).path,
    Carrier.broadnet =>
      capturedPage.host == 'www.10099.com.cn' &&
          capturedPage.path == Uri.parse(broadnetQueryUrl).path &&
          currentPage.host == 'www.10099.com.cn' &&
          currentPage.path == Uri.parse(broadnetQueryUrl).path,
    Carrier.unicom =>
      capturedPage.host == 'iservice.10010.com' &&
          ['/e5/index.html', '/e5/query.html'].contains(capturedPage.path) &&
          currentPage.host == 'iservice.10010.com' &&
          ['/e5/index.html', '/e5/query.html'].contains(currentPage.path),
    Carrier.telecom =>
      capturedPage == currentPage &&
          currentPage.host == 'e.dlife.cn' &&
          currentPage.path == '/portal/web/index.html' &&
          ['', '/'].contains(currentPage.fragment),
  };
}

bool _https(Uri uri) =>
    uri.scheme == 'https' && uri.userInfo.isEmpty && uri.port == 443;
