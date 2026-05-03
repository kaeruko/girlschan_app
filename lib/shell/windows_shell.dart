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
import '../widgets/history_panel.dart';
import '../widgets/topic_tab_bar.dart';

class WindowsShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const WindowsShell({super.key, required this.tabs});

  @override
  State<WindowsShell> createState() => _WindowsShellState();
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

class _WindowsShellState extends State<WindowsShell> {
  static const double _compactBreakpoint = 1000;
  late final Map<String, TabSpec> _tabsById;
  late final List<_SectionNavItem> _sectionItems;
  late String _selectedSectionId;
  final Map<String, GlobalKey<NavigatorState>> _sectionNavKeys = {};
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
  }

  @override
  void dispose() {
    _tabsController.dispose();
    for (final sc in _tabShortcuts) {
      sc.clear();
    }
    super.dispose();
  }

  List<_SectionNavItem> _buildSectionItems() {
    const order = [
      'tab_new',
      'tab_popular',
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
    logd('🔄 [WindowsShell] _refreshCurrentSection called');
    if (_tabsController.activeTab != null) {
      logd('🔄 [WindowsShell] detail tab is open (id=${_tabsController.activeTab!.topicId}), calling refresh callback');
      _activeShortcuts.refresh?.call();
      return;
    }

    final tabId = _selectedSectionId;
    logd('🔄 [WindowsShell] refreshing list for tab: $tabId');
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
    final existingIndex = _tabsController.tabs.indexWhere((t) => t.topicId == id);
    if (existingIndex >= 0) {
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
    return Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
              logd('⌨️ [WindowsShell] CallbackShortcuts Ctrl+R pressed');
              _refreshCurrentSection();
            },
            const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () {
              logd('⌨️ [WindowsShell] CallbackShortcuts Ctrl+Q pressed');
              windowManager.close();
            },
            const SingleActivator(LogicalKeyboardKey.f5): () {
              logd('⌨️ [WindowsShell] CallbackShortcuts F5 pressed');
              _refreshCurrentSection();
            },
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
              _activeShortcuts.focusSearch?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyG, control: true): () {
              _activeShortcuts.nextHit?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyG, control: true, shift: true): () {
              _activeShortcuts.prevHit?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true): () {
              _activeShortcuts.nextUnread?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyP, control: true, shift: true): () {
              _activeShortcuts.prevUnread?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () {
              _activeShortcuts.jumpToComment?.call();
            },
            const SingleActivator(LogicalKeyboardKey.keyW, control: true): () {
              logd('⌨️ [WindowsShell] CallbackShortcuts Ctrl+W: closing active tab');
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
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && !_isTextInputFocused()) {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
                    _activeShortcuts.scrollDownStep != null) {
                  _activeShortcuts.scrollDownStep!();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                    _activeShortcuts.scrollUpStep != null) {
                  _activeShortcuts.scrollUpStep!();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.space &&
                    _activeShortcuts.scrollDown != null) {
                  _activeShortcuts.scrollDown!();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: Scaffold(
              body: Column(
              children: [
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
                                _openInNew(id, title, comments, postedAt);
                              },
                              onTopicNewTabTap: (id, title, comments, postedAt) {
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

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.widget is EditableText;
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
      onPressed: () {
        _onSectionSelected(item.id);
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold != null && scaffold.isDrawerOpen) {
          Navigator.of(context).pop();
        }
      },
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
}
