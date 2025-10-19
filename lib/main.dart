import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:girlschan_app/config/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';

void main() async {
  // Google Drive から API ベースURL を読み込み
  await AppConfig.initializeApiBase();
  runApp(const GirlsChanApp());
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    // macOS の場合は CupertinoApp を使用
    if (Platform.isMacOS) {
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

    // iOS/Android の場合は Material Design を使用
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
