import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, Size;
import 'package:window_manager/window_manager.dart';

Future<void> initDesktopWindow() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(1200, 800),
    center: true,
    titleBarStyle: TitleBarStyle.hiddenInset,
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

Future<void> showDesktopWindow() async {
  if (await windowManager.isVisible() == false) {
    await windowManager.show();
  }
  await windowManager.focus();
}
