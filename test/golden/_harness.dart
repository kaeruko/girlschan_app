import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// アプリシェル：ゴールデンテスト用に UI 要素を固定
Widget appShell(Widget child) {
  return CupertinoApp(
    debugShowCheckedModeBanner: false,
    scrollBehavior: const _NoGlowScrollBehavior(),
    theme: const CupertinoThemeData(
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(fontFamily: 'NotoSansCJKjp'),
      ),
    ),
    home: DefaultTextStyle(
      style: const TextStyle(fontFamily: 'NotoSansCJKjp'),
      child: child,
    ),
  );
}

/// グロー効果を無効化（端末差を減らす）
class _NoGlowScrollBehavior extends CupertinoScrollBehavior {
  const _NoGlowScrollBehavior();
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

/// ゴールデンテスト用の pumpGolden 関数
/// フォント読み込み、有限回のポンプで安定化
Future<void> pumpGolden(
  WidgetTester tester,
  Widget widget, {
  Size size = const Size(390, 844), // iPhone 系デフォ
}) async {
  await loadAppFonts();
  await tester.pumpWidgetBuilder(
    appShell(widget),
    surfaceSize: size,
  );
  
  // ★ 有限回だけポンプして安定化（pumpAndSettleは使わない）
  // CupertinoSliverRefreshControl等の常時アニメータがあっても確実に先へ進む
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}
