import 'package:flutter/material.dart';
import 'new_list.dart';
import 'topic_list.dart';
import 'favorites_screen.dart';
import 'clips_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _tabs = const [
    NewListScreen(),
    TopicListScreen(),
    FavoritesScreen(),
    ClipsScreen(),
  ];

  final _titles = const [
    '新着トピック',
    '人気トピック',
    'ウォッチ',
    'クリップ',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.pinkAccent,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fiber_new), label: '新着'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: '人気'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'ウォッチ'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'クリップ'),
        ],
      ),
    );
  }
}
