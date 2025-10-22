// lib/desktop/desktop_window_io.dart
import 'dart:io';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter/painting.dart' show Alignment;

import 'package:window_manager/window_manager.dart' as wm;
import 'package:bitsdojo_window/bitsdojo_window.dart' as bdw;

class DesktopWindow {
  static Future<void> preRunInit() async {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return;

    await wm.windowManager.ensureInitialized();
    await wm.windowManager.waitUntilReadyToShow();
    await wm.windowManager.setMinimumSize(const Size(1200, 800));
    await wm.windowManager.setSize(const Size(1400, 900));
    await wm.windowManager.center();
    await wm.windowManager.show();
  }

  static void postRunInit() {
    if (!Platform.isMacOS) return;
    bdw.doWhenWindowReady(() {
      const initial = Size(1400, 900);
      bdw.appWindow.minSize = const Size(1200, 800);
      bdw.appWindow.size = initial;
      bdw.appWindow.alignment = Alignment.center; // ← FlutterのAlignment
      bdw.appWindow.show();
    });
  }
}
