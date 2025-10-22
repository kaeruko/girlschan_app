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
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          for (final t in widget.tabs)
            BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
        ],
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
      tabBuilder: (context, i) {
        // ここは必ず CupertinoTabView にしておく（iOSでの戻るアニメ等が自然になる）
        return CupertinoTabView(
          onGenerateRoute: AppRouter.onGenerateRoute,
          builder: (_) => widget.tabs[i].widget,
        );
      },
    );
  }
}
