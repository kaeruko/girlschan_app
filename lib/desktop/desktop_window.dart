import 'dart:io' show Platform;
import 'desktop_window_stub.dart'
    if (dart.library.io) 'desktop_window_macos.dart' as impl;

/// デスクトップ（macOS）のウィンドウ管理API
/// iOS では内部で即座に return するため、iOS ビルドには影響しない
class DesktopWindow {
  /// ウィンドウの初期化（runApp 前に呼ぶ）
  static Future<void> init() async {
    if (!Platform.isMacOS) return; // iOS/他は即 return
    await impl.initDesktopWindow();
  }

  /// ウィンドウを表示（最小化状態から復帰時など）
  static Future<void> show() async {
    if (!Platform.isMacOS) return;
    await impl.showDesktopWindow();
  }
}

