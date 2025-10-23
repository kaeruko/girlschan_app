import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView の UA・Cookie 初期化を集約するサービス層
class WebViewEnv {
  // アプリ共通のUA（必要ならバージョン等を付与）
  static Future<String> userAgent() async {
    final base = 'Mozilla/5.0';
    final os = Platform.isIOS
        ? 'iPhone; CPU iPhone OS like Mac OS X'
        : Platform.isMacOS
            ? 'Macintosh; Intel Mac OS X'
            : 'Unknown';
    // 必要ならアプリ名/バージョンも付ける
    return '$base ($os) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile AppWebView/1.0';
  }

  // Cookie を事前投入（ドメイン配下のセッション等）
  static Future<void> primeCookies({
    required Uri baseUri,
    Map<String, String> cookies = const {},
    bool isSecure = true,
  }) async {
    if (cookies.isEmpty) return;
    final mgr = CookieManager();
    for (final e in cookies.entries) {
      await mgr.setCookie(
        WebViewCookie(
          name: e.key,
          value: e.value,
          domain: baseUri.host,
          path: '/',
          isSecure: isSecure,
        ),
      );
    }
  }

  // 不要Cookieの掃除（ログアウト等）
  static Future<bool> clearAllCookies() {
    final mgr = CookieManager();
    return mgr.clearCookies();
  }

  // WebViewController の共通初期化
  static Future<void> primeController(WebViewController c, {String? ua}) async {
    await c.setJavaScriptMode(JavaScriptMode.unrestricted);
    await c.setBackgroundColor(const Color(0x00000000));
    await c.setUserAgent(ua ?? await userAgent());
  }
}
