import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

/// プラットフォーム対応ヘルパークラス
class PlatformHelper {
  /// 現在のプラットフォームがmacOSかどうかを判定
  static bool get isMacOS => Platform.isMacOS;

  /// 現在のプラットフォームがiOS/macOSのAppleプラットフォームかどうかを判定
  static bool get isApple => Platform.isIOS || Platform.isMacOS;

  /// プラットフォームに応じたページナビゲーションルートを返す
  static Route<T> buildPageRoute<T>({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    if (isMacOS) {
      return CupertinoPageRoute<T>(
        builder: builder,
        settings: settings,
      );
    }
    return MaterialPageRoute<T>(
      builder: builder,
      settings: settings,
    );
  }

  /// プラットフォームに応じたダイアログを表示
  static void showMessage(
    BuildContext context, {
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    final button = buttonText ?? (isMacOS ? '了解' : '確認');

    if (isMacOS) {
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
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
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
  }

  /// プラットフォームに応じたスナックバーを表示
  static void showSnackBar(BuildContext context, String message) {
    if (isMacOS) {
      // macOS ではスナックバーを使わずにダイアログで表示
      showCupertinoDialog(
        context: context,
        builder: (BuildContext context) {
          return CupertinoAlertDialog(
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// プラットフォームに応じたローディングインジケータを返す
  static Widget buildLoadingIndicator() {
    if (isMacOS) {
      return const CupertinoActivityIndicator();
    }
    return const CircularProgressIndicator();
  }

  /// プラットフォームに応じた区切り線を返す
  static Widget buildDivider() {
    if (isMacOS) {
      return Container(
        height: 0.5,
        color: CupertinoColors.separator,
      );
    }
    return const Divider();
  }
}
