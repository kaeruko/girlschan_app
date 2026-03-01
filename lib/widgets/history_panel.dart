import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../services/history_notifier.dart';
import 'topic_tile.dart';
import 'topic_tile_controller.dart';

class HistoryPanel extends StatefulWidget {
  final Function(int topicId, String title, int comments, String postedAt)? onTopicTap;

  const HistoryPanel({super.key, this.onTopicTap});

  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends State<HistoryPanel> {
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;
  final _tileController = TopicTileController();

  @override
  void initState() {
    super.initState();
    _loadWatchedTopics();
    historyUpdateNotifier.addListener(_loadWatchedTopics);
  }

  @override
  void dispose() {
    historyUpdateNotifier.removeListener(_loadWatchedTopics);
    _tileController.clear();
    super.dispose();
  }

  Future<void> _loadWatchedTopics() async {
    try {
      final topics = await getWatchedTopics();
      
      // 最終閲覧日時が新しい順
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }

    if (_watchedTopics.isEmpty) {
      return const SizedBox.shrink(); // 履歴がなければ表示しない
    }

    // 履歴がある場合はパネルを表示
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 200, // パネルの最大高さ
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(color: CupertinoColors.systemGrey4, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // パネルヘッダー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: CupertinoColors.systemGrey6,
            child: const Row(
              children: [
                Icon(CupertinoIcons.clock, size: 16, color: CupertinoColors.systemGrey),
                SizedBox(width: 8),
                Text(
                  '最近見たトピック',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          // 履歴リスト (縦スクロール)
          Expanded(
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
                  onTopicTap: widget.onTopicTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
