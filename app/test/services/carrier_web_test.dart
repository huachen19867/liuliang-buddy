import 'package:flutter_test/flutter_test.dart';
import 'package:liuliang_app/data/models.dart';
import 'package:liuliang_app/services/carrier_web.dart';

void main() {
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
}
