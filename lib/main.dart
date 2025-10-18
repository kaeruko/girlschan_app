import 'package:flutter/material.dart';
import 'package:girlschan_app/config/app_config.dart';
import 'screens/home_screen.dart';

void main() async {
  // Google Drive から API ベースURL を読み込み
  await AppConfig.initializeApiBase();
  runApp(const GirlsChanApp());
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ガールズあぷり',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
