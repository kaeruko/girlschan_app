import 'package:flutter/cupertino.dart';
import '../app/app_tabs.dart';
import '../router/app_router.dart';

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
  }

  @override
  void dispose() {
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (ctx) => widget.tabs[i].builder(ctx),
        );
      },
    );
  }
}
