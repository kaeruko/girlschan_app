import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, Size;
import 'package:window_manager/window_manager.dart';

Future<void> initDesktopWindow() async {
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

  // bitsdojo_window を使う場合の例（任意）
  // import 'package:bitsdojo_window/bitsdojo_window.dart';
  // doWhenWindowReady(() {
  //   const initialSize = Size(1400, 900);
  //   appWindow.size = initialSize;
  //   appWindow.minSize = const Size(1200, 800);
  //   appWindow.alignment = Alignment.center;
  //   appWindow.show();
  // });
}

Future<void> showDesktopWindow() async {
  if (await windowManager.isVisible() == false) {
    await windowManager.show();
  }
  await windowManager.focus();
}
