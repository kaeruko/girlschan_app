import 'package:flutter/cupertino.dart';
import '../app/app_tabs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: null,
      child: SafeArea(
        child: Row(
          children: [
            // サイドメニューバー
            Container(
              width: 60,
              color: CupertinoColors.systemGrey6,
              child: Column(
                children: List.generate(
                  kAppTabs.length,
                  (index) => Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() => _currentIndex = index);
                      },
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? CupertinoColors.systemPink.withAlpha(50)
                              : CupertinoColors.transparent,
                          border: _currentIndex == index
                              ? const Border(
                                  right: BorderSide(
                                    color: CupertinoColors.systemPink,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            kAppTabs[index].label,
                            style: TextStyle(
                              fontSize: 12,
                              color: _currentIndex == index
                                  ? CupertinoColors.systemPink
                                  : CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // コンテンツエリア
            Expanded(
              child: kAppTabs[_currentIndex].widget,
            ),
          ],
        ),
      ),
    );
  }
}
