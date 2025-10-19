import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'new_list.dart';
import 'topic_list.dart';
import 'favorites_screen.dart';
import 'clips_screen.dart';
import 'search_screen.dart';

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
    '履歴',
    'クリップ',
  ];

  @override
  Widget build(BuildContext context) {
    // macOS の場合は CupertinoTabScaffold を使用
    if (Platform.isMacOS) {
      return CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.doc), label: '新着'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.flame), label: '人気'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.bookmark), label: '履歴'),
            BottomNavigationBarItem(icon: Icon(CupertinoIcons.heart), label: 'クリップ'),
          ],
        ),
        tabBuilder: (context, index) {
          return CupertinoTabView(
            builder: (context) {
              return CupertinoPageScaffold(
                navigationBar: CupertinoNavigationBar(
                  middle: Text(_titles[index]),
                  trailing: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.search),
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: _tabs[index],
                ),
              );
            },
          );
        },
      );
    }

    // iOS/Android の場合は Material Design を使用
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.pinkAccent,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.fiber_new), label: '新着'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: '人気'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: '履歴'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'クリップ'),
        ],
      ),
    );
  }
}
