import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../services/history_notifier.dart';
import '../utils/log.dart';

class HistorySidebar extends StatefulWidget {
  final void Function(int topicId, String title, int? commentCount, String posted_at) onSelectTopic;

  const HistorySidebar({super.key, required this.onSelectTopic});

  @override
  State<HistorySidebar> createState() => _HistorySidebarState();
}

class _HistorySidebarState extends State<HistorySidebar> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    historyUpdateNotifier.addListener(_load);
  }

  @override
  void dispose() {
    historyUpdateNotifier.removeListener(_load);
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
          final title = (t['title'] as String?) ?? 'タイトル不明';
          final comments = (t['comments'] is int) ? t['comments'] as int : null;
          final posted_at = (t['posted_at'] as String?) ?? '';
          return CupertinoButton(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            onPressed: () => widget.onSelectTopic(id, title, comments, posted_at),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (comments != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'コメント $comments 件',
                        style: const TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
