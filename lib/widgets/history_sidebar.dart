import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../services/history_notifier.dart';
import '../utils/log.dart';
import 'topic_tile.dart';
import 'topic_tile_controller.dart';

class HistorySidebar extends StatefulWidget {
  final void Function(int topicId, String title, int? commentCount, String postedAt) onSelectTopic;

  const HistorySidebar({super.key, required this.onSelectTopic});

  @override
  State<HistorySidebar> createState() => _HistorySidebarState();
}

class _HistorySidebarState extends State<HistorySidebar> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final _tileController = TopicTileController();

  @override
  void initState() {
    super.initState();
    _load();
    historyUpdateNotifier.addListener(_load);
  }

  @override
  void dispose() {
    historyUpdateNotifier.removeListener(_load);
    _tileController.clear();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final topics = await getWatchedTopics();
      logd('📚 [HistorySidebar] Loaded ${topics.length} topics');
      for (var t in topics.take(3)) {
        logd('  - id=${t['id']}, title="${t['title']}", comments=${t['comments']}');
      }
      if (!mounted) return;
      setState(() {
        _items = topics;
        _loading = false;
      });
    } catch (e) {
      logd('HistorySidebar load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          '履歴はまだありません',
          style: TextStyle(color: CupertinoColors.systemGrey),
        ),
      );
    }
    return CupertinoScrollbar(
      child: ListView.separated(
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final t = _items[i];
          final id = t['id'] as int;
          
          return TopicTile(
            key: ValueKey<int>(id),
            topic: t,
            controller: _tileController,
            showThumb: true,
            // TopicTile内で期待されるシグネチャ `(int, String, int, String)` に合わせる
            onTopicTap: (topicId, title, comments, postedAt) {
              widget.onSelectTopic(topicId, title, comments, postedAt);
            },
          );
        },
        separatorBuilder: (context, __) => Container(
          height: 1,
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
    );
  }
}
