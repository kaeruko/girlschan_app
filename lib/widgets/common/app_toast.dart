import 'dart:async';
import 'package:flutter/cupertino.dart';

/// Material の `SnackBar` / `ScaffoldMessenger` 代替。
/// 
/// **Overlay** で出す。連打時はキュー制御＆重複抑制。
/// ScaffoldMessenger に依存しないので、あらゆるコンテキストで使える。
/// 
/// 使用例：
/// ```dart
/// AppToast.show(context, 'テキストをコピーしました');
/// AppToast.show(context, 'エラーが発生しました', duration: Duration(seconds: 3));
/// ```
class AppToast {
  static final _queue = <_ToastEntry>[];
  static bool _showing = false;

  /// トースト通知を表示
  /// 
  /// [message] - 表示するメッセージ
  /// [duration] - 表示時間（デフォルト 2秒）
  static Future<void> show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) async {
    if (message.trim().isEmpty) return;

    // 直前と同一メッセージの連投を抑制
    if (_queue.isNotEmpty && _queue.last.message == message) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = _ToastEntry(message, duration, overlay);
    _queue.add(entry);

    if (!_showing) {
      _showing = true;
      while (_queue.isNotEmpty) {
        final current = _queue.removeAt(0);
        await current._present();
      }
      _showing = false;
    }
  }
}

/// トースト表示用の内部エントリ
class _ToastEntry {
  final String message;
  final Duration duration;
  final OverlayState overlay;
  late final OverlayEntry _entry;

  _ToastEntry(this.message, this.duration, this.overlay);

  Future<void> _present() async {
    _entry = OverlayEntry(
      builder: (_) {
        return IgnorePointer(
          ignoring: true,
          child: Stack(
            children: [
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: _ToastBubble(message: message),
              ),
            ],
          ),
        );
      },
    );
    overlay.insert(_entry);
    await Future.delayed(duration);
    _entry.remove();
  }
}

/// トースト表示用のバブル UI
class _ToastBubble extends StatelessWidget {
  final String message;

  const _ToastBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final style = CupertinoTheme.of(context).textTheme.textStyle;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: style.copyWith(
            color: CupertinoColors.white,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
