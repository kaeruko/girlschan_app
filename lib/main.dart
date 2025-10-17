import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const GirlsChanApp());
}

class GirlsChanApp extends StatelessWidget {
  const GirlsChanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GirlsChannel Offline',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
