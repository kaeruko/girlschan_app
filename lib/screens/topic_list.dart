// lib/screens/topic_list.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import 'topic_detail.dart';

/// タイルを一括で再評価するための簡易コントローラ
class _TopicListTileController {
  final Set<_TopicListTileState> _tiles = {};

  void register(_TopicListTileState tile) => _tiles.add(tile);
  void unregister(_TopicListTileState tile) => _tiles.remove(tile);

  Future<void> refreshAll() async {
    // イテレーション中の変更を避けるため、コピーを作成
    final tilesToRefresh = List.from(_tiles);
    for (final t in tilesToRefresh) {
      if (t.mounted) await t.refreshCacheState();
    }
  }
}

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen>
    with WidgetsBindingObserver {
  static const String cacheKey = 'topics';

  final _controller = _TopicListTileController();

  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFromCache();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// アプリがフォアグラウンドに戻ったら全タイル再評価
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAll();
    }
  }

  Future<void> _loadFromCache() async {
    logd('📂 [_loadFromCache] Loading topics from cache...', name: 'TopicList');
    final cached = await CacheService.load(cacheKey);
    logd('📂 [_loadFromCache] Cached topics count: ${cached.length}', name: 'TopicList');
    if (cached.length > 0) {
      logd('📂 [_loadFromCache] First topic: ${cached[0]}', name: 'TopicList');
    }
    if (cached.isNotEmpty) {
      setState(() {
        _topics = cached.cast<Map<String, dynamic>>();
        _loading = false;
      });
      logd('✅ [_loadFromCache] Loaded ${_topics.length} topics from cache', name: 'TopicList');
    } else {
      logd('⚠️ [_loadFromCache] No cached topics, fetching from server...', name: 'TopicList');
      await _fetchFromServer();
    }
  }

  Future<void> _removeFromWatch(int topicId) async {
    await removeWatchedTopicId(topicId);
    setState(() {
      _topics.removeWhere((topic) => topic['id'] == topicId);
    });
    // 全タイルを再評価して表示を更新
    _controller.refreshAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('履歴を削除しました')),
    );
  }

  Future<void> _fetchFromServer() async {
    try {
      logd('🌐 [_fetchFromServer] Fetching popular topics from server...', name: 'TopicList');
      final topics = await fetchPopularTopicsWithCache(); // API（api_service.dart）- 人気トピック用
      final list = topics.cast<Map<String, dynamic>>();
      logd('🌐 [_fetchFromServer] Fetched ${list.length} topics from server', name: 'TopicList');
      if (list.isNotEmpty) {
        logd('🌐 [_fetchFromServer] First topic from server: ${list[0]}', name: 'TopicList');
      }
      await CacheService.save(cacheKey, list);
      logd('💾 [_fetchFromServer] Saved ${list.length} topics to cache', name: 'TopicList');

      if (!mounted) return;
      setState(() {
        _topics = list;
        _loading = false;
      });

      logd('🔄 [_fetchFromServer] Refreshing all tiles...', name: 'TopicList');
      _controller.refreshAll();
    } catch (e) {
      logd('❌ [_fetchFromServer] Error fetching from server: $e', name: 'TopicList');
      // 失敗時でもキャッシュがあれば出す
      final cached = await CacheService.load(cacheKey);
      logd('💾 [_fetchFromServer] Falling back to cached topics: ${cached.length}', name: 'TopicList');
      if (!mounted) return;
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
        }
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データの更新に失敗しました（キャッシュを使用）')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchFromServer,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Scrollbar(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: _topics.length,
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
                    return _TopicListTile(
                      topic: topic,
                      controller: _controller,
                      onRemove: _removeFromWatch,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

/// キャッシュがあるトピックを表示するカスタムタイル
class _TopicListTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final _TopicListTileController controller;
  final Function(int) onRemove;

  const _TopicListTile({
    required this.topic,
    required this.controller,
    required this.onRemove,
  });

  @override
  State<_TopicListTile> createState() => _TopicListTileState();
}

class _TopicListTileState extends State<_TopicListTile> {
  bool _hasCachedComments = false;

  @override
  void initState() {
    super.initState();
    widget.controller.register(this);
    refreshCacheState();
  }

  @override
  void dispose() {
    widget.controller.unregister(this);
    super.dispose();
  }

  Future<void> refreshCacheState() async {
    final id = widget.topic['id'];
    logd('🔍 [refreshCacheState] Checking cache for topic ID: $id', name: 'TopicList');
    final hasCached = await CacheService.exists('comments_$id');
    logd('🔍 [refreshCacheState] Topic ID: $id, hasCached: $hasCached', name: 'TopicList');
    if (!mounted) return;
    setState(() => _hasCachedComments = hasCached);
    logd('✅ [refreshCacheState] Updated _hasCachedComments for ID $id: $hasCached', name: 'TopicList');
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.topic['id'] as int;
    final title = widget.topic['title'] as String? ?? '';
    final comments = widget.topic['comments'] ?? 0;
    final time = widget.topic['time'] as String? ?? '';
    final thumb = widget.topic['thumb'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: _hasCachedComments ? Colors.blue.withOpacity(0.05) : Colors.transparent,
        border: _hasCachedComments
            ? const Border(
                left: BorderSide(
                  color: Colors.blue,
                  width: 4,
                ),
              )
            : null,
      ),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: (thumb != null && thumb.isNotEmpty)
                  ? Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                    )
                  : const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
            ),
            if (_hasCachedComments)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.normal,
            color: _hasCachedComments ? Colors.blue[800] : null,
          ),
        ),
        subtitle: Text('$commentsコメント • $time'),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => widget.onRemove(id),
        ),
        onTap: () async {
          // 詳細へ遷移 → 戻りで即再評価（自分＋全体）
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: id,
                title: title,
                commentCount: comments is int ? comments : int.tryParse('$comments') ?? 0,
              ),
            ),
          );
          if (mounted) {
            await refreshCacheState();         // 自分を更新
            widget.controller.refreshAll();    // 一覧全体も更新
          }
        },
      ),
    );
  }
}
