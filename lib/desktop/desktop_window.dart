import 'dart:io' show Platform;
import 'desktop_window_impl_stub.dart'
    if (dart.library.io) 'desktop_window_impl_macos.dart';

abstract class DesktopWindowImpl {
  Future<void> init();
  Future<void> show();
}

final DesktopWindowImpl _impl = createDesktopWindowImpl();

/// デスクトップ（macOS）のウィンドウ管理API
/// iOS では内部で即座に return するため、iOS ビルドには影響しない
class DesktopWindow {
  /// ウィンドウの初期化（runApp 前に呼ぶ）
  static Future<void> init() async {
    if (!Platform.isMacOS) return; // iOS/他は即 return
    await _impl.init();
  }

  /// ウィンドウを表示（最小化状態から復帰時など）
  static Future<void> show() async {
    if (!Platform.isMacOS) return;
    await _impl.show();
  }
}

