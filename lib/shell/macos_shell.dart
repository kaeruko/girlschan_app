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
import '../services/window_notifier.dart';
import '../widgets/history_panel.dart';

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
  late final Map<String, TabSpec> _tabsById;
  late final List<_SectionNavItem> _sectionItems;
  late String _selectedSectionId;
  final Map<String, GlobalKey<NavigatorState>> _sectionNavKeys = {};
  double _captionHeight = 28.0;
  double _leftPaneWidth = 350.0;

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
        final height = h.toDouble();
        captionHeightNotifier.value = height;
        setState(() => _captionHeight = height);
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
    // ★ ScaffoldMessenger を提供（CupertinoApp は提供しないため）
    return ScaffoldMessenger(
      child: PlatformMenuBar(
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
            const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
              logd('⌨️ [MacShell] CallbackShortcuts Cmd+R pressed (might be redundant)');
              _refreshCurrentSection();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () {
              logd('⌨️ [MacShell] CallbackShortcuts F5 pressed (might be redundant)');
              _refreshCurrentSection();
            },
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
            const SingleActivator(LogicalKeyboardKey.space): () {
              if (!_isTextInputFocused()) _topicDetailShortcuts.scrollDown?.call();
            },
            const SingleActivator(LogicalKeyboardKey.space, shift: true): () {
              if (!_isTextInputFocused()) _topicDetailShortcuts.scrollUp?.call();
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              final nav = _sectionNavKeys[_selectedSectionId]?.currentState;
              if (nav != null && nav.canPop()) {
                nav.pop();
              } else {
                _selectionController.clearSelection();
              }
            },
          },
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  if (_isTextInputFocused()) return KeyEventResult.ignored;
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
            child: Scaffold(
              body: Column(
              children: [
                // ネイティブ信号下のスペーサ
                SizedBox(height: _captionHeight),
                // メニューバー
                _buildMenuBar(),
                const Divider(height: 1),
                // 本体：2ペイン構成
                Expanded(
                  child: Row(
                    children: [
                      // 【左】トピック一覧（タブの中身）
                      SizedBox(
                        width: _leftPaneWidth,
                        child: IndexedStack(
                          index: _selectedSectionIndex,
                          children: [
                            for (final section in _sectionItems)
                              _buildCenterPaneContent(section.id),
                          ],
                        ),
                      ),

                      // ドラッグ可能な縦の区切り線
                      _buildResizableDivider(),

                      // 【右】履歴パネル＋詳細エリア
                      Expanded(
                        child: Column(
                          children: [
                            HistoryPanel(
                              onTopicTap: (id, title, comments, postedAt) {
                                _selectionController.selectTopic(
                                  id,
                                  title: title,
                                  comments: comments,
                                  postedAt: postedAt,
                                );
                              },
                            ),
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _selectionController,
                                builder: (context, _) {
                                  final selectedId = _selectionController.selectedTopicId;

                                  if (selectedId == null) {
                                    return const Center(
                                      child: Text(
                                        "トピックを選択してください",
                                        style: TextStyle(color: CupertinoColors.systemGrey),
                                      ),
                                    );
                                  }

                                  return PlatformHelper.isDesktop
                                      ? TopicDetailPane(
                                          key: ValueKey(selectedId),
                                          topicId: selectedId,
                                          title: _selectionController.title,
                                          commentCount: _selectionController.commentCount,
                                          postedAt: _selectionController.postedAt,
                                          enableRefresh: true,
                                          saveReadPosition: true,
                                          shortcutController: _topicDetailShortcuts,
                                        )
                                      : TopicDetailScreen(
                                          key: ValueKey(selectedId),
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
              ],
            ),
          ),
        ),
      ),
      ),
      ), // ScaffoldMessenger
    );
  }

  Widget _buildResizableDivider() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          setState(() {
            _leftPaneWidth = (_leftPaneWidth + details.delta.dx).clamp(200.0, 600.0);
          });
        },
        child: SizedBox(
          width: 8,
          child: Center(
            child: Container(width: 1, color: CupertinoColors.separator),
          ),
        ),
      ),
    );
  }

  /// テキスト入力フィールドにフォーカスがある場合 true を返す
  /// （IME変換中のスペースキーをスクロールに横取りしないため）
  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.widget is EditableText;
  }

  Widget _buildMenuBar() {
    return Container(
      color: CupertinoColors.systemBackground,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (final item in _sectionItems)
            _buildMenuBarItem(item),
        ],
      ),
    );
  }

  Widget _buildMenuBarItem(_SectionNavItem item) {
    final isSelected = item.id == _selectedSectionId;
    final textColor = isSelected ? CupertinoColors.activeBlue : CupertinoColors.label;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      minSize: 0,
      onPressed: () => _onSectionSelected(item.id),
      child: Text(
        item.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: textColor,
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

}
