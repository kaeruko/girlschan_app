import 'package:flutter/cupertino.dart';

/// オーバースクロール時のグロー/バウンス演出を消す。
/// 
/// プラットフォーム差（iOS/Android）の見た目を揃える。
/// アプリ全体に適用することで、一貫したスクロール体験を実現。
/// 
/// 使用例（main.dart）：
/// ```dart
/// return CupertinoApp(
///   // ...
///   scrollBehavior: const NoGlowScrollBehavior(),
/// );
/// ```
class NoGlowScrollBehavior extends CupertinoScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // グロー/バウンス演出を出さず、child をそのまま返す
    return child;
  }
}
