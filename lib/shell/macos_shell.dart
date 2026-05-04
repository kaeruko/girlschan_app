import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // AnimatedBuilder, Scaffold etc
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../app/app_tabs.dart';
import '../screens/topic_detail.dart';
import '../screens/topic_list.dart' as tl;
import '../screens/clips_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/search_screen.dart';
import '../controllers/tabs_controller.dart';
import '../controllers/topic_detail_shortcut_controller.dart';
import '../utils/platform_helper.dart';
import '../utils/log.dart';
import '../services/window_notifier.dart';
import '../widgets/history_panel.dart';
import '../widgets/topic_tab_bar.dart';

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

  // タブ管理
  final _tabsController = TabsController();
  final List<TopicDetailShortcutController> _tabShortcuts = [];
  final _noopShortcuts = TopicDetailShortcutController();

  TopicDetailShortcutController get _activeShortcuts {
    final idx = _tabsController.activeIndex;
    if (idx < 0 || idx >= _tabShortcuts.length) return _noopShortcuts;
    return _tabShortcuts[idx];
  }

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

  @override
  void dispose() {
    _tabsController.dispose();
    for (final sc in _tabShortcuts) {
      sc.clear();
    }
    super.dispose();
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
    // 詳細タブが開いている時は詳細をリロード
    if (_tabsController.activeTab != null) {
      logd('🔄 [MacShell] detail tab is open (id=${_tabsController.activeTab!.topicId}), calling refresh callback');
      _activeShortcuts.refresh?.call();
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

  void _openInCurrent(int id, String title, int comments, String postedAt) {
    final tab = TopicTab(
      topicId: id,
      title: title,
      commentCount: comments,
      postedAt: postedAt,
    );
    final wasEmpty = _tabsController.tabs.isEmpty;
    _tabsController.openInCurrent(tab);
    if (wasEmpty) {
      _tabShortcuts.add(TopicDetailShortcutController());
    }
  }

  void _openInNew(int id, String title, int comments, String postedAt) {
    logd('👆 [MacShell] _openInNew called: id=$id, title=$title', name: 'Tabs');
    final existingIndex = _tabsController.tabs.indexWhere((t) => t.topicId == id);
    logd('👆 [MacShell] existingIndex=$existingIndex, tabCount=${_tabsController.tabs.length}', name: 'Tabs');
    if (existingIndex >= 0) {
      logd('👆 [MacShell] switching to existing tab at index=$existingIndex', name: 'Tabs');
      _tabsController.setActive(existingIndex);
      return;
    }
    if (_tabsController.tabs.length >= TabsController.maxTabs) return;
    final tab = TopicTab(
      topicId: id,
      title: title,
      commentCount: comments,
      postedAt: postedAt,
    );
    _tabShortcuts.add(TopicDetailShortcutController());
    _tabsController.openInNew(tab);
  }

  void _closeTab(int index) {
    if (index < 0 || index >= _tabShortcuts.length) return;
    _tabShortcuts[index].clear();
    _tabShortcuts.removeAt(index);
    _tabsController.closeTab(index);
  }

  @override
  Widget build(BuildContext context) {
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
            PlatformMenuItem(
              label: 'Reload (F5)',
              shortcut: const SingleActivator(LogicalKeyboardKey.f5),
              onSelected: () {
                logd('⌨️ [MacShell] PlatformMenuBar F5 selected');
                _refreshCurrentSection();
              },
            ),
            PlatformMenuItem(
              label: 'Quit',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
              onSelected: () {
                logd('⌨️ [MacShell] PlatformMenuBar Cmd+Q selected');
                windowManager.close();
              },
            ),
          ],
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
              logd('⌨️ [MacShell] CallbackShortcuts Cmd+R pressed');
              _refreshCurrentSection();
            },
            const SingleActivator(LogicalKeyboardKey.keyQ, meta: true): () {
              logd('⌨️ [MacShell] CallbackShortcuts Cmd+Q pressed');
              windowManager.close();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () {
              logd('⌨️ [MacShell] CallbackShortcuts F5 pressed');
              _refreshCurrentSection();
            },
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
              _activeShortcuts.focusSearch?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () {
              _activeShortcuts.nextHit?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyG, meta: true, shift: true): () {
              _activeShortcuts.prevHit?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true): () {
              _activeShortcuts.nextUnread?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true): () {
              _activeShortcuts.prevUnread?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyJ, meta: true): () {
              _activeShortcuts.jumpToComment?.call();
            },
            const SingleActivator(LogicalKeyboardKey.space): () {
              logd('⌨️ [MacShell] CallbackShortcuts Space: scrollDown=${_activeShortcuts.scrollDown != null}');
              if (!_isTextInputFocused()) _activeShortcuts.scrollDown?.call();
            },
            const SingleActivator(LogicalKeyboardKey.space, shift: true): () {
              if (!_isTextInputFocused()) _activeShortcuts.scrollUp?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyW, meta: true): () {
              logd('⌨️ [MacShell] CallbackShortcuts Cmd+W: closing active tab');
              _closeTab(_tabsController.activeIndex);
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              final nav = _sectionNavKeys[_selectedSectionId]?.currentState;
              if (nav != null && nav.canPop()) {
                nav.pop();
              } else if (_tabsController.activeIndex >= 0) {
                _closeTab(_tabsController.activeIndex);
              }
            },
          },
          child: Focus(
            autofocus: true,
            debugLabel: 'MacShellRootFocus',
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                final key = event.logicalKey;
                final isScroll = key == LogicalKeyboardKey.space ||
                    key == LogicalKeyboardKey.arrowDown ||
                    key == LogicalKeyboardKey.arrowUp;
                // スクロールキーは常にログ出力（届いていないと何も出ない）
                if (isScroll) {
                  final textFocused = _isTextInputFocused();
                  final focusedNode = FocusManager.instance.primaryFocus;
                  final focusedWidget = focusedNode?.context?.widget;
                  final focusLabel = focusedNode?.debugLabel;
                  final activeIdx = _tabsController.activeIndex;
                  final shortcutsLen = _tabShortcuts.length;
                  final scrollDown = _activeShortcuts.scrollDown;
                  final scrollDownStep = _activeShortcuts.scrollDownStep;
                  logd('⌨️ [MacShell] onKeyEvent key=${key.keyLabel}'
                      ' textFocused=$textFocused'
                      ' focusedWidget=${focusedWidget.runtimeType}'
                      ' focusLabel=$focusLabel'
                      ' activeIdx=$activeIdx shortcutsLen=$shortcutsLen'
                      ' scrollDown=${scrollDown != null} scrollDownStep=${scrollDownStep != null}',
                      name: 'Scroll');
                }

                if (key == LogicalKeyboardKey.space) {
                  if (_isTextInputFocused()) return KeyEventResult.ignored;
                  if (HardwareKeyboard.instance.isShiftPressed) {
                    _activeShortcuts.scrollUp?.call();
                  } else {
                    _activeShortcuts.scrollDown?.call();
                  }
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowDown) {
                  final textFocused = _isTextInputFocused();
                  final step = _activeShortcuts.scrollDownStep;
                  logd('⌨️ [MacShell] ArrowDown: textFocused=$textFocused scrollDownStep=${step != null}', name: 'Scroll');
                  if (!textFocused && step != null) {
                    step();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  final textFocused = _isTextInputFocused();
                  final step = _activeShortcuts.scrollUpStep;
                  logd('⌨️ [MacShell] ArrowUp: textFocused=$textFocused scrollUpStep=${step != null}', name: 'Scroll');
                  if (!textFocused && step != null) {
                    step();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Scaffold(
              body: Column(
              children: [
                SizedBox(height: _captionHeight),
                _buildMenuBar(),
                const Divider(height: 1),
                Expanded(
                  child: Row(
                    children: [
                      // 【左】トピック一覧
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

                      _buildResizableDivider(),

                      // 【右】履歴パネル＋タブバー＋詳細エリア
                      Expanded(
                        child: Column(
                          children: [
                            HistoryPanel(
                              onTopicTap: (id, title, comments, postedAt) {
                                logd('👆 [MacShell] HistoryPanel.onTopicTap: id=$id', name: 'Tabs');
                                _openInNew(id, title, comments, postedAt);
                              },
                              onTopicNewTabTap: (id, title, comments, postedAt) {
                                logd('👆 [MacShell] HistoryPanel.onTopicNewTabTap: id=$id', name: 'Tabs');
                                _openInNew(id, title, comments, postedAt);
                              },
                            ),
                            // タブバー（タブが1枚以上のとき表示）
                            AnimatedBuilder(
                              animation: _tabsController,
                              builder: (_, __) {
                                if (_tabsController.tabs.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return TopicTabBar(
                                  tabs: _tabsController.tabs,
                                  activeIndex: _tabsController.activeIndex,
                                  onTabTap: _tabsController.setActive,
                                  onTabClose: _closeTab,
                                );
                              },
                            ),
                            // 詳細エリア
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _tabsController,
                                builder: (context, _) {
                                  final tabs = _tabsController.tabs;

                                  if (tabs.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        "トピックを選択してください",
                                        style: TextStyle(color: CupertinoColors.systemGrey),
                                      ),
                                    );
                                  }

                                  return IndexedStack(
                                    index: _tabsController.activeIndex,
                                    children: [
                                      for (int i = 0; i < tabs.length; i++)
                                        PlatformHelper.isDesktop
                                            ? TopicDetailPane(
                                                key: ValueKey(tabs[i].topicId),
                                                topicId: tabs[i].topicId,
                                                title: tabs[i].title,
                                                commentCount: tabs[i].commentCount,
                                                postedAt: tabs[i].postedAt,
                                                enableRefresh: true,
                                                saveReadPosition: true,
                                                shortcutController: _tabShortcuts[i],
                                              )
                                            : TopicDetailScreen(
                                                key: ValueKey(tabs[i].topicId),
                                                topicId: tabs[i].topicId,
                                                title: tabs[i].title,
                                                commentCount: tabs[i].commentCount,
                                                postedAt: tabs[i].postedAt,
                                                enableRefresh: true,
                                                saveReadPosition: true,
                                                shortcutController: _tabShortcuts[i],
                                              ),
                                    ],
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

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    final widget = focus?.context?.widget;
    final result = widget is EditableText;
    if (result) {
      logd('⌨️ [MacShell] _isTextInputFocused=true: focusedWidget=${widget.runtimeType} label=${focus?.debugLabel}', name: 'Scroll');
    }
    return result;
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

  Widget _buildCenterPaneContent(String sectionId) {
    final spec = _tabsById[sectionId];
    if (spec == null) {
      return const SizedBox.shrink();
    }
    if (spec.id == 'tab_new' || spec.id == 'tab_popular') {
      final key = spec.stateKey;
      return tl.TopicListScreen(
        key: key is GlobalKey<tl.TopicListScreenState> ? key : null,
        sortOrder: spec.id == 'tab_new' ? 'new' : 'popular',
        onTopicTap: (id, title, comments, postedAt) {
          _openInNew(id, title, comments, postedAt);
        },
        onTopicNewTabTap: (id, title, comments, postedAt) {
          _openInNew(id, title, comments, postedAt);
        },
      );
    }

    if (spec.id == 'tab_favorites') {
      final key = spec.stateKey;
      return FavoritesScreen(
        key: key is GlobalKey<FavoritesScreenState> ? key : null,
        onTopicTap: (id, title, comments, postedAt) {
          _openInNew(id, title, comments, postedAt);
        },
        onTopicNewTabTap: (id, title, comments, postedAt) {
          _openInNew(id, title, comments, postedAt);
        },
      );
    }

    if (spec.id == 'tab_clips') {
      final key = spec.stateKey;
      return ClipsScreen(
        key: key is GlobalKey<ClipsScreenState> ? key : null,
        onTopicTap: (id, title, comments, postedAt) {
          _openInNew(id, title, comments, postedAt);
        },
        onTopicNewTabTap: (id, title, comments, postedAt) {
          _openInNew(id, title, comments, postedAt);
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
                _openInNew(id, title, comments, postedAt);
              },
              onTopicNewTabTap: (id, title, comments, postedAt) {
                _openInNew(id, title, comments, postedAt);
              },
            ),
            settings: settings,
          );
        },
      );
    }

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
