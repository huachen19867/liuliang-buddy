import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/carrier_web.dart';

void main() {
  test(
    'number-auth agreement opens only its exact official HTTPS document',
    () {
      const contract =
          'https://wap.cmpassport.com/resources/html/contract.html';
      expect(isMobileNumberAuthAgreement(Uri.parse(contract)), isTrue);
      expect(
        isMobileNumberAuthAgreement(Uri.parse('$contract#privacy')),
        isTrue,
      );
      for (final url in [
        'http://wap.cmpassport.com/resources/html/contract.html',
        'https://wap.cmpassport.com.evil.test/resources/html/contract.html',
        'https://user@wap.cmpassport.com/resources/html/contract.html',
        'https://wap.cmpassport.com:444/resources/html/contract.html',
        'https://wap.cmpassport.com/resources/html/other.html',
        '$contract?redirect=https://example.com',
      ]) {
        expect(isMobileNumberAuthAgreement(Uri.parse(url)), isFalse);
      }
      expect(
        isCarrierNavigationAllowed(Carrier.mobile, Uri.parse(contract)),
        isFalse,
        reason: 'agreement must not replace the login WebView',
      );
    },
  );
  test(
    'mobile rendered balance requires current official homepage identity',
    () {
      final home = Uri.parse(carrierQueryUrl(Carrier.mobile));
      expect(
        isCarrierResponseAllowed(
          Carrier.mobile,
          home,
          home,
          'mobileBalanceRendered',
        ),
        isTrue,
      );
      for (final invalid in [
        Uri.parse(carrierLoginUrl(Carrier.mobile)),
        home.replace(scheme: 'http'),
        home.replace(port: 444),
        home.replace(host: 'wx.10086.cn.evil.test'),
        home.replace(path: '/website/spa/main/newHomeExtra'),
        home.replace(fragment: '/login'),
      ]) {
        expect(
          isCarrierResponseAllowed(
            Carrier.mobile,
            invalid,
            invalid,
            'mobileBalanceRendered',
          ),
          isFalse,
        );
      }
      expect(
        isCarrierResponseAllowed(
          Carrier.mobile,
          home.replace(query: 'old=1'),
          home,
          'mobileBalanceRendered',
        ),
        isFalse,
      );
      expect(
        isCarrierResponseAllowed(Carrier.mobile, home, home, 'raw'),
        isFalse,
      );
      final flow = Uri.parse(
        'https://wx.10086.cn/website/serviceMargin/getNewMarginInfo',
      );
      expect(
        isCarrierResponseAllowed(Carrier.mobile, flow, home, 'raw'),
        isTrue,
      );
      expect(
        isCarrierResponseAllowed(
          Carrier.mobile,
          flow,
          Uri.parse(carrierLoginUrl(Carrier.mobile)),
          'raw',
        ),
        isFalse,
      );
      expect(
        isCarrierResponseAllowed(
          Carrier.mobile,
          flow,
          home,
          'mobileBalanceRendered',
        ),
        isFalse,
      );
    },
  );

  test(
    'Unicom session signal requires its exact minimized response identity',
    () {
      final page = Uri.parse(carrierQueryUrl(Carrier.unicom));
      final url = Uri.parse(
        'https://iservice.10010.com/e3/static/check/checklogin/',
      );
      expect(
        isCarrierResponseAllowed(Carrier.unicom, url, page, 'unicomSession'),
        isTrue,
      );
      for (final invalid in [
        url.replace(query: 'profile=private'),
        url.replace(fragment: 'private'),
        url.replace(path: '/e3/static/check/checklogin/extra'),
        url.replace(host: 'uac.10010.com'),
        url.replace(path: '/e3/static/query/userinfoE5query'),
      ]) {
        expect(
          isCarrierResponseAllowed(
            Carrier.unicom,
            invalid,
            page,
            'unicomSession',
          ),
          isFalse,
        );
      }
      expect(
        isCarrierResponseAllowed(Carrier.unicom, url, page, 'raw'),
        isFalse,
      );
    },
  );

  test(
    'four carrier URLs and SSO navigation stay with their intended carrier',
    () {
      for (final carrier in Carrier.values) {
        expect(
          isCarrierNavigationAllowed(
            carrier,
            Uri.parse(carrierLoginUrl(carrier)),
          ),
          isTrue,
        );
        expect(
          isCarrierNavigationAllowed(
            carrier,
            Uri.parse(carrierQueryUrl(carrier)),
          ),
          isTrue,
        );
        expect(
          isCarrierNavigationAllowed(carrier, Uri.parse('https://evil.test')),
          isFalse,
        );
      }
      expect(
        isCarrierNavigationAllowed(
          Carrier.telecom,
          Uri.parse('https://e.dlife.cn.evil.test/'),
        ),
        isFalse,
      );
      expect(
        isCarrierNavigationAllowed(
          Carrier.telecom,
          Uri.parse('https://evil.dlife.cn/'),
        ),
        isFalse,
      );
      expect(
        isCarrierNavigationAllowed(
          Carrier.unicom,
          Uri.parse('https://www.10099.com.cn/'),
        ),
        isFalse,
      );
    },
  );
  test(
    'Unicom observation accepts only the E5 balance endpoint on a query page',
    () {
      final page = Uri.parse(carrierQueryUrl(Carrier.unicom));
      final url = Uri.parse(
        'https://iservice.10010.com/e3/static/query/userinfoE5query?_=123',
      );
      expect(
        isCarrierResponseAllowed(Carrier.unicom, url, page, 'raw'),
        isTrue,
      );
      for (final bad in [
        'http://iservice.10010.com/e3/static/query/userinfoE5query',
        'https://iservice.10010.com:444/e3/static/query/userinfoE5query',
        'https://iservice.10010.com/e3/static/check/checklogin/',
        'https://iservice.10010.com/e3/static/query/userinfoE5queryOther',
      ]) {
        expect(
          isCarrierResponseAllowed(Carrier.unicom, Uri.parse(bad), page, 'raw'),
          isFalse,
        );
      }
      expect(
        isCarrierResponseAllowed(
          Carrier.unicom,
          url,
          Uri.parse(carrierLoginUrl(Carrier.unicom)),
          'raw',
        ),
        isFalse,
      );
    },
  );
  test(
    'Telecom rendered records require the current home route and exact stage',
    () {
      final home = Uri.parse(carrierQueryUrl(Carrier.telecom));
      expect(
        isCarrierResponseAllowed(
          Carrier.telecom,
          home,
          home,
          'telecomRendered',
        ),
        isTrue,
      );
      expect(
        isCarrierResponseAllowed(Carrier.telecom, home, home, 'raw'),
        isFalse,
      );
      final login = Uri.parse(carrierLoginUrl(Carrier.telecom));
      expect(
        isCarrierResponseAllowed(
          Carrier.telecom,
          login,
          login,
          'telecomRendered',
        ),
        isFalse,
      );
      final other = Uri.parse(
        'https://e.dlife.cn/portal/web/index.html#/settings',
      );
      expect(
        isCarrierResponseAllowed(
          Carrier.telecom,
          other,
          other,
          'telecomRendered',
        ),
        isFalse,
      );
      expect(
        isCarrierResponseAllowed(
          Carrier.telecom,
          home,
          Uri.parse('https://e.dlife.cn/marketing/'),
          'telecomRendered',
        ),
        isFalse,
      );
      expect(isCarrierLoginPage(login), isTrue);
      expect(
        isCarrierLoginPage(Uri.parse(carrierLoginUrl(Carrier.unicom))),
        isTrue,
      );
    },
  );

  test('current official balance page accepts harmless URL changes only', () {
    final mobile = Uri.parse(carrierQueryUrl(Carrier.mobile));
    expect(
      isCarrierResponsePageCurrent(
        Carrier.mobile,
        mobile,
        mobile.replace(query: 'from=refresh'),
      ),
      isTrue,
    );
    expect(
      isCarrierResponsePageCurrent(
        Carrier.mobile,
        mobile,
        mobile.replace(fragment: '/login'),
      ),
      isFalse,
    );
    final broadnet = Uri.parse(carrierQueryUrl(Carrier.broadnet));
    expect(
      isCarrierResponsePageCurrent(
        Carrier.broadnet,
        broadnet,
        broadnet.replace(query: 'tab=traffic'),
      ),
      isTrue,
    );
    expect(
      isCarrierResponsePageCurrent(
        Carrier.broadnet,
        broadnet,
        Uri.parse(carrierLoginUrl(Carrier.broadnet)),
      ),
      isFalse,
    );
    final unicom = Uri.parse(carrierQueryUrl(Carrier.unicom));
    expect(
      isCarrierResponsePageCurrent(
        Carrier.unicom,
        unicom,
        Uri.parse('https://iservice.10010.com/e5/query.html?tab=flow'),
      ),
      isTrue,
    );
    for (final bad in [
      Uri.parse(carrierLoginUrl(Carrier.unicom)),
      Uri.parse('https://iservice.10010.com.evil.test/e5/query.html'),
      Uri.parse('https://iservice.10010.com/e5/query.html#/login'),
      Uri.parse('https://iservice.10010.com/e5/marketing.html'),
    ]) {
      expect(
        isCarrierResponsePageCurrent(Carrier.unicom, unicom, bad),
        isFalse,
      );
    }
    final telecom = Uri.parse(carrierQueryUrl(Carrier.telecom));
    expect(
      isCarrierResponsePageCurrent(Carrier.telecom, telecom, telecom),
      isTrue,
    );
    expect(
      isCarrierResponsePageCurrent(
        Carrier.telecom,
        telecom,
        telecom.replace(fragment: '/login'),
      ),
      isFalse,
    );
  });

  test('Mobile login help states the official App does not sync Web login', () {
    expect(mobileLoginHelpMessage, contains('中国移动官方 App'));
    expect(mobileLoginHelpMessage, contains('不会自动同步'));
    expect(mobileLoginHelpMessage, contains('暂不支持自动查询'));
    expect(
      mobileLoginHelpMessage,
      contains('https://www.10086.cn/cmccclient/'),
    );
  });
}
