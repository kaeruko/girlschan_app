import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../config/app_config.dart';
import 'topic_detail.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchedTopics();
  }

  Future<void> _loadWatchedTopics() async {
    final topics = await getWatchedTopics();
    setState(() {
      _watchedTopics = topics;
      _loading = false;
    });
  }

  Future<void> _refreshWatched() async {
    setState(() => _loading = true);
    await _loadWatchedTopics();
  }

  Future<void> _removeFromWatch(int topicId) async {
    await removeWatchedTopicId(topicId);
    setState(() {
      _watchedTopics.removeWhere((topic) => topic['id'] == topicId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('履歴を削除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_watchedTopics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '履歴に登録されたトピックはありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'トピック詳細の📘をタップして登録',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshWatched,
      child: ListView.builder(
        itemCount: _watchedTopics.length,
        itemBuilder: (context, i) {
          final topic = _watchedTopics[i];
          return _FavoritesTile(topic: topic, onRemove: _removeFromWatch);
        },
      ),
    );
  }
}

// キャッシュがあるトピックを表示するカスタムタイル
class _FavoritesTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final Function(int) onRemove;

  const _FavoritesTile({
    required this.topic,
    required this.onRemove,
  });

  @override
  State<_FavoritesTile> createState() => _FavoritesTileState();
}

class _FavoritesTileState extends State<_FavoritesTile> {
  bool _hasCachedComments = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    final id = widget.topic['id'] as int;
    final hasCached = await CacheService.exists('comments_$id');
    setState(() {
      _hasCachedComments = hasCached;
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.topic['id'] as int;
    final title = widget.topic['title'] as String? ?? 'タイトル不明';
    final comments = widget.topic['comments'] as int? ?? 0;
    final time = widget.topic['time'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _hasCachedComments 
            ? Colors.blue.withOpacity(0.05) 
            : Colors.transparent,
        border: _hasCachedComments
            ? Border(
                left: BorderSide(
                  color: Colors.blue,
                  width: 4,
                ),
              )
            : null,
      ),
      child: ListTile(
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.w500,
            color: _hasCachedComments ? Colors.blue[800] : null,
          ),
        ),
        subtitle: Text(
          'コメント: $comments件 $time',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => widget.onRemove(id),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: id,
                title: title,
                commentCount: comments,
              ),
            ),
          );
        },
      ),
    );
  }
}
