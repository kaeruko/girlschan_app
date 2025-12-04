import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // AnimatedBuilder, Scaffold etc
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../app/app_tabs.dart';
import '../widgets/history_sidebar.dart';
import '../screens/topic_detail.dart';
import '../screens/topic_list.dart' as tl;
import '../screens/clips_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/search_screen.dart';
import '../controllers/selection_controller.dart'; // ★追加

class MacShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const MacShell({super.key, required this.tabs});

  @override
  State<MacShell> createState() => _MacShellState();
}

class _MacShellState extends State<MacShell> {
  int _index = 0;
  late final List<TabSpec> _effectiveTabs;
  // NavigatorKeys は 3ペイン化で不要になる可能性があるが、
  // 検索画面や設定画面など、ドリルダウンが必要なタブのために残す
  late final List<GlobalKey<NavigatorState>> _tabNavKeys;
  late final GlobalKey<ClipsScreenState> _clipsKey;
  late final GlobalKey<FavoritesScreenState> _favoritesKey;
  double _captionHeight = 28.0;

  // ★ 選択状態を管理
  final _selectionController = SelectionController();

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
    _refreshCurrentTab();
  }

  void _refreshCurrentTab() {
    final tabId = _effectiveTabs[_index].id;

    // ★ 履歴タブのリロード（型安全）
    if (tabId == 'tab_favorites') {
      _favoritesKey.currentState?.reloadFromOutside();
    }
    // ★ クリップタブのリロード（型安全）
    if (tabId == 'tab_clips') {
      _clipsKey.currentState?.reloadFromOutside();
    }
    // ★ 新着・人気タブのリフレッシュ（TopicListScreenState）
    if (tabId == 'tab_new' || tabId == 'tab_popular') {
      final key = _effectiveTabs[_index].stateKey;
      if (key is GlobalKey<tl.TopicListScreenState>) {
        key.currentState?.refreshTiles();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ★ InkWell を反応させるため、全体を Material でラップ
    return Material(
      type: MaterialType.transparency, // 背景色を変えずにMaterial機能だけ提供
      child: CallbackShortcuts(
        bindings: {
          // Cmd + R (または F5) でリロード
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
            _refreshCurrentTab();
          },
          const SingleActivator(LogicalKeyboardKey.f5): () {
            _refreshCurrentTab();
          },
          // Esc で戻る（詳細画面を開いている時など）
          const SingleActivator(LogicalKeyboardKey.escape): () {
            // 3ペインの場合、Escで選択解除などが考えられるが、
            // とりあえず既存のNavigatorがあればpopする
            final nav = _tabNavKeys[_index].currentState;
            if (nav != null && nav.canPop()) {
              nav.pop();
            } else {
              // 選択解除
              _selectionController.clearSelection();
            }
          },
        },
        child: Focus(
          autofocus: true, // キーイベントを受け取るために必要
          child: Scaffold( // CupertinoPageScaffold から Scaffold に変更（Material Widgetを使うため）
            body: Column(
            children: [
              // ネイティブ信号下のスペーサ
              SizedBox(height: _captionHeight),
              // 上バー：タブ切替のみ（更新ボタンは置かない）
              _buildTopTabBar(),
              // 本体：3ペイン構成
              Expanded(
                child: Row(
                  children: [
                    // 【左】サイドバー（履歴など）
                    SizedBox(
                      width: 250,
                      child: HistorySidebar(
                        onSelectTopic: (id, title, count, posted_at) {
                          // 選択状態を更新
                          _selectionController.selectTopic(
                            id,
                            title: title,
                            comments: count ?? 0,
                            postedAt: posted_at,
                          );
                        },
                      ),
                    ),
                    
                    // 縦の区切り線
                    const VerticalDivider(width: 1),

                    // 【中】トピック一覧（タブの中身）
                    SizedBox(
                      width: 350,
                      child: IndexedStack(
                        index: _index,
                        children: [
                          for (int i = 0; i < _effectiveTabs.length; i++)
                            _buildCenterPaneContent(i),
                        ],
                      ),
                    ),

                    // 縦の区切り線
                    const VerticalDivider(width: 1),

                    // 【右】詳細エリア（選択状態に応じて中身が変わる）
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _selectionController,
                        builder: (context, _) {
                          final selectedId = _selectionController.selectedTopicId;
                          
                          if (selectedId == null) {
                            // 何も選ばれていない時
                            return const Center(
                              child: Text(
                                "トピックを選択してください",
                                style: TextStyle(color: CupertinoColors.systemGrey),
                              ),
                            );
                          }

                          // 選ばれていれば詳細画面を埋め込む
                          return TopicDetailScreen(
                            key: ValueKey(selectedId), // IDが変わったら作り直す
                            topicId: selectedId,
                            title: _selectionController.title,
                            commentCount: _selectionController.commentCount,
                            posted_at: _selectionController.postedAt,
                            enableRefresh: true,
                            saveReadPosition: true,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// センターペインのコンテンツをビルド
  Widget _buildCenterPaneContent(int index) {
    final spec = _effectiveTabs[index];

    // 新着・人気タブは TopicListScreen を直接生成してコールバックを渡す
    if (spec.id == 'tab_new' || spec.id == 'tab_popular') {
      return tl.TopicListScreen(
        key: spec.stateKey,
        sortOrder: spec.id == 'tab_new' ? 'new' : 'popular',
        onTopicTap: (id, title, comments, postedAt) {
          _selectionController.selectTopic(
            id,
            title: title,
            comments: comments,
            postedAt: postedAt,
          );
        },
      );
    }

    // その他のタブ（履歴、クリップなど）は既存の Navigator 構成を維持
    // ※ これらも onTopicTap 対応すれば Navigator 不要にできるが、
    //    今回は TopicListScreen を優先
    return Navigator(
      key: _tabNavKeys[index],
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          Widget screen;
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
                      fontWeight: i == _index ? FontWeight.w600 : FontWeight.normal,
                      color: i == _index
                          ? CupertinoColors.label
                          : CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            if (i < _effectiveTabs.length - 1)
              const SizedBox(width: 8),
          ],
          const Spacer(),
          // 検索アイコン追加
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onPressed: () {
              // 今アクティブなタブの Navigator を取ってくる
              final nav = _tabNavKeys[_index].currentState;
              if (nav == null) return;

              nav.push(
                CupertinoPageRoute(
                  builder: (_) => const SearchScreen(),
                ),
              );
            },
            child: const Icon(
              CupertinoIcons.search,
              size: 22,
              color: CupertinoColors.activeBlue,
            ),
          ),
        ],
      ),
    );
  }
}
