import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../config/app_config.dart';
import 'topic_detail.dart';

// グローバルキー管理用クラス
class _FavoritesTileController {
  final Set<_FavoritesTileState> _tiles = {};

  void register(_FavoritesTileState tile) {
    _tiles.add(tile);
  }

  void unregister(_FavoritesTileState tile) {
    _tiles.remove(tile);
  }

  void refreshAll() {
    for (var tile in _tiles) {
      tile._checkCache();
    }
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;
  late _FavoritesTileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _FavoritesTileController();
    WidgetsBinding.instance.addObserver(this);
    _loadWatchedTopics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻ったときに全タイルを再チェック
      _controller.refreshAll();
    }
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
    // 全タイルを再評価して表示を更新
    _controller.refreshAll();
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
      child: Scrollbar(
        child: ListView.builder(
          itemCount: _watchedTopics.length,
          itemBuilder: (context, i) {
            final topic = _watchedTopics[i];
            return _FavoritesTile(
              topic: topic,
              onRemove: _removeFromWatch,
              controller: _controller,
            );
          },
        ),
      ),
    );
  }
}

// キャッシュがあるトピックを表示するカスタムタイル
class _FavoritesTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final Function(int) onRemove;
  final _FavoritesTileController controller;

  const _FavoritesTile({
    required this.topic,
    required this.onRemove,
    required this.controller,
  });

  @override
  State<_FavoritesTile> createState() => _FavoritesTileState();
}

class _FavoritesTileState extends State<_FavoritesTile> {
  bool _hasCachedComments = false;
  int _cachedCommentCount = 0;
  int _savedCommentNo = 0;  // 復元対象のコメント番号

  @override
  void initState() {
    super.initState();
    widget.controller.register(this);
    _checkCache();
  }

  @override
  void dispose() {
    widget.controller.unregister(this);
    super.dispose();
  }

  Future<void> _checkCache() async {
    final id = widget.topic['id'] as int;
    final hasCached = await CacheService.exists('comments_$id');
    
    // SharedPreferencesからキャッシュされたコメント数と保存位置を取得
    int cachedCount = 0;
    int savedCommentNo = 0;
    if (hasCached) {
      final prefs = await SharedPreferences.getInstance();
      cachedCount = prefs.getInt('synced_$id') ?? 0;
      savedCommentNo = prefs.getInt('scroll_$id') ?? 0;
    }
    
    if (mounted) {
      setState(() {
        _hasCachedComments = hasCached;
        _cachedCommentCount = cachedCount;
        _savedCommentNo = savedCommentNo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.topic['id'] as int;
    final title = widget.topic['title'] as String? ?? 'タイトル不明';
    final comments = widget.topic['comments'] as int? ?? 0;
    final time = widget.topic['time'] as String? ?? '';

    // キャッシュ数/総数形式でコメント数を表示、保存位置があれば追加表示
    final commentDisplay = _hasCachedComments 
        ? '${_savedCommentNo > 0 ? '$_savedCommentNo' : ''}/$comments件'
        : '$comments件';

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
          'コメント: $commentDisplay $time',
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
