import 'package:flutter/material.dart';
import '../app/app_tabs.dart';
import '../router/app_router.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentTab = kAppTabs[_currentIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(currentTab.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              AppRouter.pushSearch(context);
            },
          ),
        ],
      ),
      body: currentTab.widget,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.pinkAccent,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          for (final tab in kAppTabs)
            BottomNavigationBarItem(
              icon: Icon(tab.icon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
