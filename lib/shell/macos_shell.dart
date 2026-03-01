import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // AnimatedBuilder, Scaffold etc
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../app/app_tabs.dart';
import '../screens/topic_detail.dart';
import '../screens/topic_list.dart' as tl;
import '../screens/clips_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/search_screen.dart'; // ★追加
import '../controllers/selection_controller.dart'; // ★追加
import '../controllers/topic_detail_shortcut_controller.dart';
import '../utils/platform_helper.dart';
import '../utils/log.dart'; // ★追加

class MacShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const MacShell({super.key, required this.tabs});

  @override
  State<MacShell> createState() => _MacShellState();
}

class _SectionNavItem {
  final String id;
  final String label;
  final IconData icon;

  const _SectionNavItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _MacShellState extends State<MacShell> {
  static const double _compactBreakpoint = 1000;
  late final Map<String, TabSpec> _tabsById;
  late final List<_SectionNavItem> _sectionItems;
  late String _selectedSectionId;
  final Map<String, GlobalKey<NavigatorState>> _sectionNavKeys = {};
  double _captionHeight = 28.0;

  // ★ 選択状態を管理
  final _selectionController = SelectionController();
  final _topicDetailShortcuts = TopicDetailShortcutController();

  @override
  void initState() {
    super.initState();
    _tabsById = {for (final tab in widget.tabs) tab.id: tab};
    _sectionItems = _buildSectionItems();
    _selectedSectionId = _sectionItems.first.id;
    _sectionNavKeys.addEntries(
      _sectionItems
          .where((item) => _usesNestedNavigator(item.id))
          .map((item) => MapEntry(item.id, GlobalKey<NavigatorState>())),
    );
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

  List<_SectionNavItem> _buildSectionItems() {
    const order = [
      'tab_new',
      'tab_popular',
      'tab_favorites',
      'tab_clips',
      'tab_search',
      'tab_settings',
    ];

    final items = <_SectionNavItem>[];
    for (final id in order) {
      final spec = _tabsById[id];
      if (spec == null) continue;
      items.add(
        _SectionNavItem(
          id: spec.id,
          label: spec.label,
          icon: spec.icon,
        ),
      );
    }
    return items;
  }

  bool _usesNestedNavigator(String sectionId) {
    return sectionId == 'tab_favorites' ||
        sectionId == 'tab_clips' ||
        sectionId == 'tab_search' ||
        sectionId == 'tab_settings';
  }

  void _onSectionSelected(String sectionId) {
    if (_selectedSectionId == sectionId) return;
    setState(() => _selectedSectionId = sectionId);
    _refreshCurrentSection();
  }

  void _refreshCurrentSection() {
    logd('🔄 [MacShell] _refreshCurrentSection called');
    // 詳細が開いている時は詳細をリロード
    if (_selectionController.selectedTopicId != null) {
      logd('🔄 [MacShell] detail is open (id=${_selectionController.selectedTopicId}), calling refresh callback');
      _topicDetailShortcuts.refresh?.call();
      return;
    }

    final tabId = _selectedSectionId;
    logd('🔄 [MacShell] refreshing list for tab: $tabId');
    final spec = _tabsById[tabId];

    if (spec == null) return;

    if (tabId == 'tab_favorites') {
      final key = spec.stateKey;
      if (key is GlobalKey<FavoritesScreenState>) {
        key.currentState?.reloadFromOutside();
      }
    }

    if (tabId == 'tab_clips') {
      final key = spec.stateKey;
      if (key is GlobalKey<ClipsScreenState>) {
        key.currentState?.reloadFromOutside();
      }
    }

    if (tabId == 'tab_new' || tabId == 'tab_popular') {
      final key = spec.stateKey;
      if (key is GlobalKey<tl.TopicListScreenState>) {
        key.currentState?.reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ★ InkWell を反応させるため、全体を Material でラップ
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: 'Reload',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyR, meta: true),
              onSelected: () {
                 logd('⌨️ [MacShell] PlatformMenuBar Cmd+R selected');
                _refreshCurrentSection();
              },
            ),
            // F5もサポートする場合（メニューには出ないかもしれないがショートカットとして）
             PlatformMenuItem(
              label: 'Reload (F5)',
              shortcut: const SingleActivator(LogicalKeyboardKey.f5),
              onSelected: () {
                 logd('⌨️ [MacShell] PlatformMenuBar F5 selected');
                _refreshCurrentSection();
              },
            ),
          ],
        ),
      ],
      child: Material(
        type: MaterialType.transparency, // 背景色を変えずにMaterial機能だけ提供
        child: CallbackShortcuts(
          bindings: {
            // CallbackShortcuts はフォーカスがある時用として残しておくが、
            // PlatformMenuBar があればそちらが優先されるはず。
            // ログを入れておく
            const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
              logd('⌨️ [MacShell] CallbackShortcuts Cmd+R pressed (might be redundant)');
              _refreshCurrentSection();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () {
              logd('⌨️ [MacShell] CallbackShortcuts F5 pressed (might be redundant)');
              _refreshCurrentSection();
            },
            // 検索・ヒット移動・未読移動・ジャンプ
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
              _topicDetailShortcuts.focusSearch?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () {
              _topicDetailShortcuts.nextHit?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyG, meta: true, shift: true): () {
              _topicDetailShortcuts.prevHit?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true): () {
              _topicDetailShortcuts.nextUnread?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true): () {
              _topicDetailShortcuts.prevUnread?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyJ, meta: true): () {
              _topicDetailShortcuts.jumpToComment?.call();
            },
            // スペースキーで下スクロール（ブラウザ風）
            const SingleActivator(LogicalKeyboardKey.space): () {
              _topicDetailShortcuts.scrollDown?.call();
            },
            // Shift+スペースキーで上スクロール
            const SingleActivator(LogicalKeyboardKey.space, shift: true): () {
              _topicDetailShortcuts.scrollUp?.call();
            },
            // Esc で戻る（詳細画面を開いている時など）
            const SingleActivator(LogicalKeyboardKey.escape): () {
              // 3ペインの場合、Escで選択解除などが考えられるが、
              // とりあえず既存のNavigatorがあればpopする
              final nav = _sectionNavKeys[_selectedSectionId]?.currentState;
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
            // スペースキーはフォーカスが子に移っても処理するため onKeyEvent で直接ハンドル
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    _topicDetailShortcuts.scrollUp?.call();
                  } else {
                    _topicDetailShortcuts.scrollDown?.call();
                  }
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Scaffold( // CupertinoPageScaffold から Scaffold に変更（Material Widgetを使うため）
              body: Column(
              children: [
                // ネイティブ信号下のスペーサ
                SizedBox(height: _captionHeight),
                // 本体：3ペイン構成
                Expanded(
                  child: Row(
                    children: [
                      // 【左】セクションナビ
                      SizedBox(
                        width: 220,
                        child: _buildSectionNav(),
                      ),
                      
                      // 縦の区切り線
                      const VerticalDivider(width: 1),
  
                      // 【中】トピック一覧（タブの中身）
                      SizedBox(
                        width: 350,
                        child: IndexedStack(
                          index: _selectedSectionIndex,
                          children: [
                            for (final section in _sectionItems)
                              _buildCenterPaneContent(section.id),
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
                            return PlatformHelper.isDesktop
                                ? TopicDetailPane(
                                    key: ValueKey(selectedId), // IDが変わったら作り直す
                                    topicId: selectedId,
                                    title: _selectionController.title,
                                    commentCount: _selectionController.commentCount,
                                    postedAt: _selectionController.postedAt,
                                    enableRefresh: true,
                                    saveReadPosition: true,
                                    shortcutController: _topicDetailShortcuts,
                                  )
                                : TopicDetailScreen(
                                    key: ValueKey(selectedId), // IDが変わったら作り直す
                                    topicId: selectedId,
                                    title: _selectionController.title,
                                    commentCount: _selectionController.commentCount,
                                    postedAt: _selectionController.postedAt,
                                    enableRefresh: true,
                                    saveReadPosition: true,
                                    shortcutController: _topicDetailShortcuts,
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
      ),
    );
  }

  /// センターペインのコンテンツをビルド
  Widget _buildCenterPaneContent(String sectionId) {
    final spec = _tabsById[sectionId];
    if (spec == null) {
      return const SizedBox.shrink();
    }
    // 新着・人気タブは TopicListScreen を直接生成してコールバックを渡す
    if (spec.id == 'tab_new' || spec.id == 'tab_popular') {
      final key = spec.stateKey;
      return tl.TopicListScreen(
        key: key is GlobalKey<tl.TopicListScreenState> ? key : null,
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
    // 履歴・クリップもここで直接ハンドリングして onTopicTap を渡す
    if (spec.id == 'tab_favorites') {
      final key = spec.stateKey;
      return FavoritesScreen(
        key: key is GlobalKey<FavoritesScreenState> ? key : null,
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
    
    if (spec.id == 'tab_clips') {
      final key = spec.stateKey;
      return ClipsScreen(
        key: key is GlobalKey<ClipsScreenState> ? key : null,
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

    if (spec.id == 'tab_search') {
      return Navigator(
        key: _sectionNavKeys[spec.id],
        onGenerateRoute: (settings) {
          return CupertinoPageRoute(
            builder: (_) => SearchScreen(
              initialQuery: null,
              onTopicTap: (id, title, comments, postedAt) {
                 _selectionController.selectTopic(
                  id,
                  title: title,
                  comments: comments,
                  postedAt: postedAt,
                );
              },
            ),
            settings: settings,
          );
        },
      );
    }

    // その他のタブ（設定など）は既存の Navigator 構成を維持
    if (_usesNestedNavigator(spec.id)) {
      return Navigator(
        key: _sectionNavKeys[spec.id],
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            Widget screen;
            screen = spec.builder(context);
            return CupertinoPageRoute(
              builder: (_) => screen,
              settings: settings,
            );
          }
          return null;
        },
      );
    }

    return spec.builder(context);
  }

  int get _selectedSectionIndex {
    final index = _sectionItems.indexWhere((item) => item.id == _selectedSectionId);
    return index >= 0 ? index : 0;
  }

  Widget _buildSectionNav() {
    return Container(
      color: CupertinoColors.systemGrey6,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        children: [
          for (final item in _sectionItems)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _buildSectionNavItem(item),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionNavItem(_SectionNavItem item) {
    final isSelected = item.id == _selectedSectionId;
    final textColor = isSelected ? CupertinoColors.systemPink : CupertinoColors.label;
    final iconColor = isSelected ? CupertinoColors.systemPink : CupertinoColors.secondaryLabel;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        _onSectionSelected(item.id);
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.isDrawerOpen) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? CupertinoColors.systemGrey4 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(item.icon, size: 18, color: iconColor),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
