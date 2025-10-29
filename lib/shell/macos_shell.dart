import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';
import '../app/app_tabs.dart';
import '../widgets/history_sidebar.dart';
import '../screens/topic_detail.dart';
import '../screens/clips_screen.dart';
import '../screens/favorites_screen.dart';

class MacShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const MacShell({super.key, required this.tabs});

  @override
  State<MacShell> createState() => _MacShellState();
}

class _MacShellState extends State<MacShell> {
  int _index = 0;
  late final List<TabSpec> _effectiveTabs;
  late final List<GlobalKey<NavigatorState>> _tabNavKeys;
  late final GlobalKey<ClipsScreenState> _clipsKey;
  late final GlobalKey<FavoritesScreenState> _favoritesKey;
  double _captionHeight = 28.0;

  @override
  void initState() {
    super.initState();
    _effectiveTabs = widget.tabs.where((t) =>
      t.id == 'tab_new' || t.id == 'tab_popular' || t.id == 'tab_favorites' || t.id == 'tab_clips'
    ).toList();

    _tabNavKeys = List.generate(_effectiveTabs.length, (_) => GlobalKey<NavigatorState>());
    _clipsKey = GlobalKey<ClipsScreenState>();
    _favoritesKey = GlobalKey<FavoritesScreenState>();
    _loadCaptionHeight();
  }

  Future<void> _loadCaptionHeight() async {
    try {
      final h = await windowManager.getTitleBarHeight();
      if (!mounted) return;
      if (h != null && h > 0) {
        setState(() => _captionHeight = h.toDouble());
      }
    } catch (_) {
      // 取得できない環境では fallback の 28.0 を使う
    }
  }

  void _onTabChanged(int newIndex) {
    setState(() => _index = newIndex);
    final tabId = _effectiveTabs[newIndex].id;

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
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: null,
      child: Column(
        children: [
          // ネイティブ信号下のスペーサ
          SizedBox(height: _captionHeight),
          // 上バー：タブ切替のみ（更新ボタンは置かない）
          _buildTopTabBar(),
          // 本体：左＝履歴サイドバー、右＝タブ内容
          Expanded(
            child: Row(
              children: [
                // 左サイド（キャッシュ履歴）
                SizedBox(
                  width: 260,
                  child: HistorySidebar(
                    onSelectTopic: (id, title, count, posted_at) {
                      // 現在タブの Navigator に詳細を push
                      final nav = _tabNavKeys[_index].currentState;
                      if (nav != null) {
                        nav.push(CupertinoPageRoute(
                          builder: (_) => TopicDetailScreen(
                            topicId: id,
                            title: title,
                            commentCount: count ?? 0,
                            posted_at: posted_at, 
                          ),
                        ));
                      }
                    },
                  ),
                ),
                Container(width: 1, color: CupertinoColors.separator),
                // 右ペイン（タブの中身）
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      for (int i = 0; i < _effectiveTabs.length; i++)
                        Navigator(
                          key: _tabNavKeys[i],
                          onGenerateRoute: (settings) {
                            if (settings.name == '/') {
                              final spec = _effectiveTabs[i];
                              Widget screen;
                              // ★ GlobalKey を各スクリーンに渡す
                              if (spec.id == 'tab_clips') {
                                screen = ClipsScreen(key: _clipsKey);
                              } else if (spec.id == 'tab_favorites') {
                                screen = FavoritesScreen(key: _favoritesKey);
                              } else {
                                screen = spec.builder(context);
                              }
                              return CupertinoPageRoute(
                                builder: (_) => screen,
                                settings: settings,
                              );
                            }
                            return null;
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 上バー：タブ切替のみ
  Widget _buildTopTabBar() {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemGrey6,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (int i = 0; i < _effectiveTabs.length; i++) ...[
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              onPressed: () => _onTabChanged(i),
              child: Row(
                children: [
                  Icon(
                    _effectiveTabs[i].icon,
                    size: 16,
                    color: i == _index
                        ? CupertinoColors.systemPink
                        : CupertinoColors.secondaryLabel,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _effectiveTabs[i].label,
                    style: TextStyle(
                      fontSize: 13,
                      color: i == _index
                          ? CupertinoColors.systemPink
                          : CupertinoColors.label,
                      fontWeight: i == _index ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (i < _effectiveTabs.length - 1) const SizedBox(width: 4),
          ],
          const Spacer(),
          // 検索アイコン追加
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onPressed: () {
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('検索'),
                  content: const Text('検索画面（仮）'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('閉じる'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            },
            child: const Icon(CupertinoIcons.search, size: 22, color: CupertinoColors.activeBlue),
          ),
        ],
      ),
    );
  }
}
