import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../desktop/desktop_window.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/inline_notice.dart';

/// テストで上書き可能なプラットフォーム識別
enum PlatformKind { iOS, macOS, android, windows, linux, web }

/// OS判定・ルーティング・ダイアログなど、プラットフォーム依存処理の窓口
class PlatformHelper {
  static PlatformKind? _override; // テスト用。通常は null のまま。

  // ===== 判定系 =====
  static bool get isMacOS =>
      _override != null ? _override == PlatformKind.macOS : Platform.isMacOS;
  static bool get isIOS =>
      _override != null ? _override == PlatformKind.iOS : Platform.isIOS;
  static bool get isAndroid => _override != null
      ? _override == PlatformKind.android
      : Platform.isAndroid;
  static bool get isWindows => _override != null
      ? _override == PlatformKind.windows
      : Platform.isWindows;
  static bool get isApple => isMacOS || isIOS;

  static bool get isDesktop => isMacOS || isWindows;
  static bool get isMobile => isIOS || isAndroid;

  /// テスト用：明示的にプラットフォームを上書き（テスト終了時は reset）
  static void setTestPlatform(PlatformKind? kind) {
    if (!kDebugMode) return; // 本番ビルドで誤用しないための保険
    _override = kind;
  }

  // ===== ルーティング（Cupertino統一） =====
  static Route<T> cupertinoRoute<T>(
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) {
    return CupertinoPageRoute<T>(builder: builder, settings: settings);
  }

  /// 従来の buildPageRoute（後方互換性）
  static Route<T> buildPageRoute<T>({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    return cupertinoRoute(builder, settings: settings);
  }

  // ===== ローディング・通知（統一窓口） =====
  static Widget buildLoadingIndicator({double size = 16}) =>
      AppSpinner(size: size);

  /// 画面上部に薄いお知らせ
  static Widget buildInlineNotice(
    String text, {
    bool isError = false,
    VoidCallback? onClose,
  }) {
    return InlineNotice(text: text, isError: isError, onClose: onClose);
  }

  // ===== 触覚フィードバック（あるなら軽く） =====
  static Future<void> lightHaptic() async {
    if (isApple) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {}
    }
  }

  // ===== デスクトップウィンドウ初期化（macOSのみ） =====
  static Future<void> initDesktopWindowIfNeeded() async {
    if (isDesktop) {
      await DesktopWindow.init();
    }
  }

  static Future<void> showDesktopWindowIfNeeded() async {
    if (isMacOS) {
      await DesktopWindow.show();
    }
  }

  // ===== トースト通知（AppToast 統一） =====
  static Future<void> showSnackBar(BuildContext context, String message) {
    return AppToast.show(context, message);
  }

  // ===== 汎用ダイアログ（Cupertino標準に寄せる） =====
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String message,
    String okText = 'OK',
    String cancelText = 'キャンセル',
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(okText),
          ),
        ],
      ),
    );
  }

  /// Cupertino区切り線を返す
  static Widget buildDivider() {
    return Container(height: 0.5, color: CupertinoColors.separator);
  }
}
