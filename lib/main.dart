import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_config.dart';
import 'app/app_tabs.dart';
import 'shell/adaptive_shell.dart';
import 'desktop/desktop_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // macOS だけウィンドウ初期化
  if (Platform.isMacOS) {
    await DesktopWindow.init();
  }

  try {
    print('🚀 AppConfig 初期化開始');
    await AppConfig.initializeApiBase();
    print('✅ AppConfig 初期化完了: ${AppConfig.apiBase}');
  } catch (e, stackTrace) {
    print('❌ AppConfig 初期化失敗: $e');
    print('❌ スタックトレース: $stackTrace');
    AppConfig.apiBase = 'https://evhch6a2hc.execute-api.us-west-2.amazonaws.com/dev';
  }

  runApp(const GirlsChanApp());
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'がるちゃんあぷり',
      locale: const Locale('ja', 'JP'),
      localizationsDelegates: const [
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, 
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
        Locale('en', 'US'),
      ],
      home: AdaptiveShell(tabs: kAppTabs),
    );
  }
}
