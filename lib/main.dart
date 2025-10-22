import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:girlschan_app/config/app_config.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'dart:io';
import 'app/app_tabs.dart';
import 'shell/ios_shell.dart';
import 'shell/macos_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // macOS/Windows/Linuxでウィンドウサイズを設定
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setMinimumSize(const Size(1200, 800));
      await windowManager.setSize(const Size(1400, 900));
      await windowManager.center();
      await windowManager.show();
    });
  }
  
  try {
    print('🚀 AppConfig 初期化開始');
    await AppConfig.initializeApiBase();
    print('✅ AppConfig 初期化完了: ${AppConfig.apiBase}');
  } catch (e, stackTrace) {
    print('❌ AppConfig 初期化失敗: $e');
    print('❌ スタックトレース: $stackTrace');
    // ここでも強制的にフォールバック値を設定
    AppConfig.apiBase = 'https://evhch6a2hc.execute-api.us-west-2.amazonaws.com/dev';
  }
  
  runApp(const GirlsChanApp());

  // bitsdojo_window の初期化（macOSでのウィンドウ制御）
  if (Platform.isMacOS) {
    doWhenWindowReady(() {
      const initialSize = Size(1400, 900);
      appWindow.minSize = const Size(1200, 800);
      appWindow.size = initialSize;
      appWindow.alignment = Alignment.center;
      appWindow.show();
    });
  }
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    // フェーズ1の kAppTabs を使う
    final tabs = kAppTabs;

    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'がるちゃんあぷり',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemPink,
        textTheme: CupertinoTextThemeData(),
      ),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('ja'),
        Locale('en'),
      ],
      // プラットフォーム分岐
      home: Platform.isMacOS ? MacShell(tabs: tabs) : IOSShell(tabs: tabs),
    );
  }
}
