import 'package:flutter/cupertino.dart';
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

  final _labels = const [
    '新着',
    '人気',
    '履歴',
    'クリップ',
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: null,
      child: SafeArea(
        child: Column(
          children: [
            // トップメニューバー
            Container(
              height: 50,
              color: CupertinoColors.systemGrey6,
              child: Row(
                children: List.generate(
                  _tabs.length,
                  (index) => Expanded(
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() => _currentIndex = index);
                      },
                      child: Container(
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? CupertinoColors.systemPink.withAlpha(50)
                              : Colors.transparent,
                          border: _currentIndex == index
                              ? const Border(
                                  bottom: BorderSide(
                                    color: CupertinoColors.systemPink,
                                    width: 3,
                                  ),
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            _labels[index],
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
              child: _tabs[_currentIndex],
            ),
          ],
        ),
      ),
    );
  }
}
