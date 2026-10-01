import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// The vendored iOS plugin reads this extra creation setting before creating
/// WKWebView. A primary account leaves it absent and uses WebKit's default
/// persistent data store, preserving existing logins.
class AccountWebViewSettings extends InAppWebViewSettings {
  AccountWebViewSettings({this.profileName})
    : super(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        thirdPartyCookiesEnabled: false,
        allowFileAccess: false,
        allowContentAccess: false,
      );

  final String? profileName;

  @override
  Map<String, dynamic> toMap() {
    final settings = super.toMap();
    if (profileName != null) {
      settings['liuliangAccountProfile'] = profileName;
    }
    return settings;
  }
}

class IOSAccountProfiles {
  IOSAccountProfiles._();

  static const channel = MethodChannel(
    'com.pichillilorenzo/flutter_inappwebview_manager',
  );

  static Future<bool> supported() async =>
      await channel.invokeMethod<bool>('liuliangSupportsAccountProfiles') ??
      false;

  static Future<void> clearAll() async {
    final cleared = await channel.invokeMethod<bool>(
      'liuliangDeleteAccountProfiles',
    );
    if (cleared != true) {
      throw PlatformException(
        code: 'account_profiles_not_cleared',
        message: 'Persistent iOS account stores were not cleared',
      );
    }
  }
}
