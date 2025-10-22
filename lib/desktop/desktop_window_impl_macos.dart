import 'dart:io' show Platform;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, Size;
import 'package:window_manager/window_manager.dart';

abstract class DesktopWindowImpl {
  Future<void> init();
  Future<void> show();
}

class _MacOSDesktopWindowImpl implements DesktopWindowImpl {
  @override
  Future<void> init() async {
    assert(Platform.isMacOS, 'This implementation is for macOS only');

    // window_manager の初期化
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1400, 900),
      minimumSize: Size(1200, 800),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: null,
      fullScreen: false,
      skipTaskbar: false,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // ウィンドウ装飾と表示の最終調整
      await windowManager.setResizable(true);
      await windowManager.setMinimizable(true);
      await windowManager.setMaximizable(true);
      await windowManager.setClosable(true);
      await windowManager.setHasShadow(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  @override
  Future<void> show() async {
    if (await windowManager.isVisible() == false) {
      await windowManager.show();
    }
    await windowManager.focus();
  }
}

/// 条件付き import で呼ばれるファクトリ
/// macOS ではこれが使われる
DesktopWindowImpl createDesktopWindowImpl() => _MacOSDesktopWindowImpl();
