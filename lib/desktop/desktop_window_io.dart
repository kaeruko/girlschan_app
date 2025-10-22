import 'dart:io';
import 'package:flutter/widgets.dart';

// デスクトップでだけ使うパッケージ
import 'package:window_manager/window_manager.dart' as wm;
import 'package:bitsdojo_window/bitsdojo_window.dart' as bdw;

/// デスクトップ（macOS/Windows/Linux）のウィンドウ管理をファサードする
/// iOS では内部で即座に return するため、iOS ビルドには影響しない
class DesktopWindow {
  /// runApp() の前に呼ぶ初期化
  /// window_manager による基本設定（サイズ、位置など）
  static Future<void> preRunInit() async {
    // iOS は即座に return（実行されない）
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) return;

    await wm.windowManager.ensureInitialized();
    await wm.windowManager.waitUntilReadyToShow();
    await wm.windowManager.setMinimumSize(const Size(1200, 800));
    await wm.windowManager.setSize(const Size(1400, 900));
    await wm.windowManager.center();
    await wm.windowManager.show();
  }

  /// runApp() の後に呼ぶ後処理
  /// bitsdojo_window による詳細制御（macOS/Windows/Linux）
  /// await しない（バックグラウンドで実行）
  static void postRunInit() {
    // iOS と Windows/Linux は処理なし
    if (!Platform.isMacOS) return;

    // macOS のみ、bitsdojo で追加制御
    bdw.doWhenWindowReady(() {
      const initialSize = Size(1400, 900);
      bdw.appWindow.minSize = const Size(1200, 800);
      bdw.appWindow.size = initialSize;
      bdw.appWindow.alignment = bdw.Alignment.center;
      bdw.appWindow.show();
    });
  }
}
