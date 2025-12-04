import 'package:flutter/widgets.dart' show WidgetsFlutterBinding, Size, Offset; // ★Offsetを追加
import 'package:window_manager/window_manager.dart';

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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

  // 画面外に行かないように簡易チェック（必要なら）
  // ここではシンプルに保存された値があれば使う

  final windowOptions = WindowOptions(
    size: size,
    minimumSize: const Size(1200, 800),
    center: (x == null || y == null), // 保存された位置がなければ中央
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: null,
    fullScreen: false,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 位置の復元（center: false の場合のみ有効だが、waitUntilReadyToShow内でセットされる）
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

  // リスナー登録
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
