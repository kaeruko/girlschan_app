import 'package:flutter/cupertino.dart';
import '../app/app_tabs.dart';
import '../screens/clips_screen.dart';
import '../screens/favorites_screen.dart';

class IOSShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const IOSShell({super.key, required this.tabs});

  @override
  State<IOSShell> createState() => _IOSShellState();
}

class _IOSShellState extends State<IOSShell> {
  late final CupertinoTabController _controller;
  late final GlobalKey<ClipsScreenState> _clipsKey;
  late final GlobalKey<FavoritesScreenState> _favoritesKey;

  @override
  void initState() {
    super.initState();
    _controller = CupertinoTabController(initialIndex: 0);
    _controller.addListener(_onTabChanged);
    _clipsKey = GlobalKey<ClipsScreenState>();
    _favoritesKey = GlobalKey<FavoritesScreenState>();
  }

  void _onTabChanged() {
    final idx = _controller.index;
    final tabId = kAppTabs[idx].id;

    // ★ 履歴タブのリロード（型安全）
    if (tabId == 'tab_favorites') {
      _favoritesKey.currentState?.reloadFromOutside();
    }
    // ★ クリップタブのリロード（型安全）
    if (tabId == 'tab_clips') {
      _clipsKey.currentState?.reloadFromOutside();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _controller,
      tabBar: CupertinoTabBar(
        items: [
          for (final t in widget.tabs)
            BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
        ],
      ),
      tabBuilder: (context, i) {
        final spec = widget.tabs[i];
        // ★ GlobalKey を各タブに渡す
        switch (spec.id) {
          case 'tab_clips':
            return CupertinoTabView(
              builder: (_) => ClipsScreen(key: _clipsKey),
            );
          case 'tab_favorites':
            return CupertinoTabView(
              builder: (_) => FavoritesScreen(key: _favoritesKey),
            );
          default:
            return CupertinoTabView(
              builder: spec.builder,
            );
        }
      },
    );
  }
}
