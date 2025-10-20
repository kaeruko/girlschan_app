import 'package:flutter/material.dart';
import 'package:girlschan_app/config/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    return MaterialApp(
      title: 'がるちゃんあぷり',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/search') ?? false) {
          final uri = Uri.parse(settings.name!);
          final query = uri.queryParameters['q'] ?? '';
          return MaterialPageRoute(
            builder: (context) => SearchScreen(initialQuery: query),
          );
        }
        return null;
      },
    );
  }
}
