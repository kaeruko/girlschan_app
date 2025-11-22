import 'dart:async';
import 'package:flutter/cupertino.dart';

/// Overlay ベースのトースト。
/// どの画面からでも使える & タップでアクション実行可能。
class AppToast {
  static final _queue = <_ToastEntry>[];
  static bool _showing = false;

  static Future<void> show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 5),
    VoidCallback? onTap,
  }) async {
    if (message.trim().isEmpty) return;

    // 同じメッセージの連投を抑制
    if (_queue.isNotEmpty && _queue.last.message == message) return;

    // ★ 常にルート Navigator の Overlay を使う
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) {
      return;
    }

    _queue.add(_ToastEntry(
      message: message,
      duration: duration,
      overlay: overlay,
      onTap: onTap,
    ));

    if (_showing) return;

    _showing = true;
    while (_queue.isNotEmpty) {
      final current = _queue.removeAt(0);
      await current.present();
    }
    _showing = false;
  }
}

class _ToastEntry {
  _ToastEntry({
    required this.message,
    required this.duration,
    required this.overlay,
    this.onTap,
  });

  final String message;
  final Duration duration;
  final OverlayState overlay;
  final VoidCallback? onTap;

  late final OverlayEntry _entry;
  bool _dismissed = false;

  Future<void> present() async {
    void dismiss() {
      if (_dismissed) return;
      _dismissed = true;
      // ★ すでに remove 済み / overlay dispose 済みなら何もしない
      if (_entry.mounted) {
        _entry.remove();
      }
    }

    _entry = OverlayEntry(
      builder: (ctx) {
        return IgnorePointer(
          ignoring: false, // タップを通す
          child: Stack(
            children: [
              Positioned(
                left: 24,
                right: 24,
                bottom: 80, // タブバーの少し上
                child: _ToastBubble(
                  message: message,
                  onTap: () {
                    onTap?.call();
                    dismiss(); // タップした瞬間に閉じる
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_entry);
    try {
      await Future.delayed(duration);
    } catch (_) {
      // キャンセルされても無視
    }
    dismiss();
  }
}

class _ToastBubble extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const _ToastBubble({
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = CupertinoTheme.of(context).textTheme.textStyle;
    return Center(
      child: GestureDetector(
        onTap: onTap,
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
      ),
    );
  }
}
