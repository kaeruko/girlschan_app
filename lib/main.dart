import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_config.dart';
import 'app/app_tabs.dart';
import 'shell/adaptive_shell.dart';
import 'desktop/desktop_window.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // デスクトップ系の事前初期化（iOSはノーオペ）
  await DesktopWindow.preRunInit();

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

  // ラン後フック（bitsdojoの doWhenWindowReady など）
  DesktopWindow.postRunInit(); // await しない
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'がるちゃんあぷり',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemPink,
        textTheme: CupertinoTextThemeData(),
      ),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('ja'),
        Locale('en'),
      ],
      // プラットフォーム依存を AdaptiveShell に隠す
      home: AdaptiveShell(tabs: kAppTabs),
    );
  }
}
