import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/app_config.dart';
import 'app/app_tabs.dart';
import 'shell/adaptive_shell.dart';
import 'utils/platform_helper.dart';
import 'utils/log.dart';
import 'utils/route_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // macOS ウィンドウ初期化（PlatformHelper 経由）
  await PlatformHelper.initDesktopWindowIfNeeded();

  try {
    logd('🚀 AppConfig 初期化開始');
    await AppConfig.initializeApiBase();
    logd('✅ AppConfig 初期化完了: ${AppConfig.apiBase}');
  } catch (e, stackTrace) {
    logd('❌ AppConfig 初期化失敗: $e');
    logd('❌ スタックトレース: $stackTrace');
    AppConfig.apiBase = 'https://evhch6a2hc.execute-api.us-west-2.amazonaws.com/dev';
  }

  runApp(const GirlsChanApp());
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
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
      navigatorObservers: [routeObserver],
      // iOS: ボトムタブ / macOS: 上バー＋履歴サイドバー を内包
      home: AdaptiveShell(tabs: kAppTabs),
    );
  }
}
