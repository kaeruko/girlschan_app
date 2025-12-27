import 'dart:async';

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, Offset, Size;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

Future<void> initDesktopWindow() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // 保存されたウィンドウサイズ・位置を読み込む
  final double? width = prefs.getDouble('window_width');
  final double? height = prefs.getDouble('window_height');
  final double? x = prefs.getDouble('window_x');
  final double? y = prefs.getDouble('window_y');

  Size size = const Size(1400, 900);
  if (width != null && height != null) {
    size = Size(width, height);
  }

  final windowOptions = WindowOptions(
    size: size,
    minimumSize: const Size(1200, 800),
    center: (x == null || y == null),
    titleBarStyle: TitleBarStyle.normal,
    backgroundColor: null,
    fullScreen: false,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }

    await windowManager.setResizable(true);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(true);
    await windowManager.setClosable(true);
    await windowManager.setHasShadow(true);
    await windowManager.show();
    await windowManager.focus();
  });

  windowManager.addListener(_WindowObserver(prefs));
}

class _WindowObserver extends WindowListener {
  final SharedPreferences prefs;
  Timer? _debounceTimer;

  _WindowObserver(this.prefs);

  void _saveState() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final size = await windowManager.getSize();
        final pos = await windowManager.getPosition();
        await prefs.setDouble('window_width', size.width);
        await prefs.setDouble('window_height', size.height);
        await prefs.setDouble('window_x', pos.dx);
        await prefs.setDouble('window_y', pos.dy);
      } catch (_) {}
    });
  }

  @override
  void onWindowResize() {
    _saveState();
  }

  @override
  void onWindowMove() {
    _saveState();
  }
}

Future<void> showDesktopWindow() async {
  if (await windowManager.isVisible() == false) {
    await windowManager.show();
  }
  await windowManager.focus();
}
