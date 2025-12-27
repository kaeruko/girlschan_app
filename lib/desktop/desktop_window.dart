import 'dart:io' show Platform;

import 'desktop_window_stub.dart'
    if (dart.library.io) 'desktop_window_macos.dart' as mac_impl;
import 'desktop_window_stub.dart'
    if (dart.library.io) 'desktop_window_windows.dart' as windows_impl;

/// デスクトップ（macOS/Windows）のウィンドウ管理API
/// iOS では内部で即座に return するため、iOS ビルドには影響しない
class DesktopWindow {
  /// ウィンドウの初期化（runApp 前に呼ぶ）
  static Future<void> init() async {
    if (Platform.isMacOS) {
      await mac_impl.initDesktopWindow();
    } else if (Platform.isWindows) {
      await windows_impl.initDesktopWindow();
    }
  }

  /// ウィンドウを表示（最小化状態から復帰時など）
  static Future<void> show() async {
    if (Platform.isMacOS) {
      await mac_impl.showDesktopWindow();
    } else if (Platform.isWindows) {
      await windows_impl.showDesktopWindow();
    }
  }
}
