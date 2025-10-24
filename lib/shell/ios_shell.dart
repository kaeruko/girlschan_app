import 'package:flutter/cupertino.dart';
import '../app/app_tabs.dart';
import '../utils/route_observer.dart';

class IOSShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const IOSShell({super.key, required this.tabs});

  @override
  State<IOSShell> createState() => _IOSShellState();
}

class _IOSShellState extends State<IOSShell> {
  late final CupertinoTabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CupertinoTabController(initialIndex: 0);
    _controller.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final idx = _controller.index;
    final tabId = kAppTabs[idx].id;

    // ★ 履歴タブのリロード（型安全）
    if (tabId == 'tab_favorites') {
      favoritesScreenStateKey.currentState?.reloadFromOutside();
    }
    // ★ クリップタブのリロード（型安全）
    if (tabId == 'tab_clips') {
      clipsScreenStateKey.currentState?.reloadFromOutside();
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
        // ← currentIndex / onTap は指定しない（CupertinoTabScaffold が自動で制御）
      ),
      tabBuilder: (context, i) {
        // ここは必ず CupertinoTabView にしておく（iOSでの戻るアニメ等が自然になる）
        return CupertinoTabView(
          navigatorObservers: [routeObserver],
          builder: (ctx) => widget.tabs[i].builder(ctx),
        );
      },
    );
  }
}
