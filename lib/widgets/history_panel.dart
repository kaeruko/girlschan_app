import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/history_notifier.dart';
import '../services/settings_service.dart';
import 'topic_tile.dart';
import 'topic_tile_controller.dart';

class HistoryPanel extends StatefulWidget {
  final Function(int topicId, String title, int comments, String postedAt)? onTopicTap;
  final Function(int topicId, String title, int comments, String postedAt)? onTopicNewTabTap;

  const HistoryPanel({super.key, this.onTopicTap, this.onTopicNewTabTap});

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;
  bool _collapsed = false;
  double _panelHeight = 200.0;
  final _tileController = TopicTileController();
  final _settings = SettingsService();

  static const _prefKeyCollapsed = 'history_panel_collapsed';
  static const _prefKeyHeight = 'history_panel_height';
  static const double _minHeight = 80.0;
  static const double _maxHeight = 500.0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadWatchedTopics();
    historyUpdateNotifier.addListener(_loadWatchedTopics);
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    historyUpdateNotifier.removeListener(_loadWatchedTopics);
    _settings.removeListener(_onSettingsChanged);
    _tileController.clear();
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _collapsed = prefs.getBool(_prefKeyCollapsed) ?? false;
        _panelHeight = (prefs.getDouble(_prefKeyHeight) ?? 200.0)
            .clamp(_minHeight, _maxHeight);
      });
    }
  }

  Future<void> _setCollapsed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyCollapsed, value);
    if (mounted) setState(() => _collapsed = value);
  }

  Future<void> _savePanelHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKeyHeight, height);
  }

  Future<void> _loadWatchedTopics() async {
    try {
      final topics = await getWatchedTopics();

      topics.sort((a, b) {
        final timeA = DateTime.tryParse(a['watchedAt'] ?? '') ?? DateTime(0);
        final timeB = DateTime.tryParse(b['watchedAt'] ?? '') ?? DateTime(0);
        return timeB.compareTo(timeA);
      });

      if (!mounted) return;
      setState(() {
        _watchedTopics = topics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _removeItem(int topicId) async {
    await removeWatchedTopicId(topicId);
    historyUpdateNotifier.value++;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _watchedTopics.isEmpty) {
      return const SizedBox.shrink();
    }

    // 折りたたみ時：細いバーだけ表示
    if (_collapsed) {
      return GestureDetector(
        onTap: () => _setCollapsed(false),
        child: Container(
          height: 28,
          color: CupertinoColors.systemGrey6,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              Icon(CupertinoIcons.clock, size: 13, color: CupertinoColors.systemGrey),
              SizedBox(width: 6),
              Text(
                '最近見たトピック',
                style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
              ),
              Spacer(),
              Icon(CupertinoIcons.chevron_down, size: 12, color: CupertinoColors.systemGrey),
            ],
          ),
        ),
      );
    }

    // 展開時：フルパネル
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _panelHeight,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: CupertinoColors.systemGrey4, width: 1.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ヘッダー
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: CupertinoColors.systemGrey6,
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.clock, size: 16, color: CupertinoColors.systemGrey),
                      const SizedBox(width: 8),
                      const Text(
                        '最近見たトピック',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minSize: 24,
                        onPressed: () => _setCollapsed(true),
                        child: const Icon(CupertinoIcons.chevron_up, size: 14, color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                ),
                // 履歴リスト
                Expanded(
                  child: Container(
                    color: _settings.backgroundColor,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _watchedTopics.length,
                      itemBuilder: (context, index) {
                        final topic = _watchedTopics[index];
                        final id = topic['id'] as int;
                        return TopicTile(
                          key: ValueKey<int>(id),
                          topic: topic,
                          controller: _tileController,
                          showThumb: true,
                          alwaysShowRemove: true,
                          onRemove: (topicId) async {
                            await _removeItem(topicId);
                          },
                          onTopicTap: widget.onTopicTap,
                          onTopicNewTabTap: widget.onTopicNewTabTap,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // リサイズハンドル
        MouseRegion(
          cursor: SystemMouseCursors.resizeRow,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: (details) {
              setState(() {
                _panelHeight = (_panelHeight + details.delta.dy)
                    .clamp(_minHeight, _maxHeight);
              });
            },
            onVerticalDragEnd: (_) {
              _savePanelHeight(_panelHeight);
            },
            child: Container(
              height: 6,
              color: CupertinoColors.systemGrey5,
              child: Center(
                child: Container(
                  width: 32,
                  height: 2,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey3,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
