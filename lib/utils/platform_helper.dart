import 'package:flutter/cupertino.dart';
import '../widgets/common/app_toast.dart';

/// macOS専用ヘルパークラス
class PlatformHelper {
  /// CupertinoPageRoute を返す
  static Route<T> buildPageRoute<T>({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: settings,
    );
  }

  /// CupertinoAlertDialog を表示
  static void showMessage(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    final button = buttonText ?? '了解';

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                Navigator.of(context).pop();
                onPressed?.call();
              },
              child: Text(button),
            ),
          ],
        );
      },
    );
  }

  /// 画面下部にトースト通知を表示（AppToast で置換）
  static Future<void> showSnackBar(BuildContext context, String message) {
    return AppToast.show(context, message);
  }

  /// CupertinoActivityIndicator を返す
  static Widget buildLoadingIndicator() {
    return const CupertinoActivityIndicator();
  }

  /// Cupertino区切り線を返す
  static Widget buildDivider() {
    return Container(
      height: 0.5,
      color: CupertinoColors.separator,
    );
  }
}
