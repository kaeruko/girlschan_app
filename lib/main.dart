import 'package:flutter/cupertino.dart';
import 'package:girlschan_app/config/app_config.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';

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
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'がるちゃんあぷり',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemPink,
        textTheme: CupertinoTextThemeData(),
      ),
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/search') ?? false) {
          final uri = Uri.parse(settings.name!);
          final query = uri.queryParameters['q'] ?? '';
          return CupertinoPageRoute(
            builder: (context) => SearchScreen(initialQuery: query),
          );
        }
        return null;
      },
    );
  }
}
