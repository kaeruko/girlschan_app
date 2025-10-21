// lib/screens/new_list.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import 'topic_detail.dart';

/// タイルを一括で再評価するための簡易コントローラ
class _TopicTileController {
  final Set<_TopicTileState> _tiles = {};

  void register(_TopicTileState tile) => _tiles.add(tile);
  void unregister(_TopicTileState tile) => _tiles.remove(tile);

  Future<void> refreshAll() async {
    // イテレーション中の変更を避けるため、コピーを作成
    final tilesToRefresh = List.from(_tiles);
    for (final t in tilesToRefresh) {
      // 画面内／外に関係なく安全に再チェック
      if (t.mounted) await t.refreshCacheState();
    }
  }
}

/// 一覧の1行（キャッシュ有無で見た目が変化）
class _TopicTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final _TopicTileController controller;
  final Function(int) onRemove;

  const _TopicTile({
    required this.topic,
    required this.controller,
    required this.onRemove,
  });

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile> {
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
    logd('🔍 [NewList.refreshCacheState] Checking cache for topic ID: $id', name: 'NewList');
    final hasCached = await CacheService.exists('comments_$id');
    logd('🔍 [NewList.refreshCacheState] Topic ID: $id, hasCached: $hasCached', name: 'NewList');
    if (!mounted) return;
    setState(() => _hasCachedComments = hasCached);
    logd('✅ [NewList.refreshCacheState] Updated _hasCachedComments for ID $id: $hasCached', name: 'NewList');
  }

  @override
  Widget build(BuildContext context) {
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
              width: 64,
              height: 64,
              child: (thumb != null && thumb.isNotEmpty)
                  ? Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
                    )
                  : const Icon(Icons.image_not_supported),
            ),
            if (_hasCachedComments)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
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
            fontSize: 15,
            fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.normal,
            color: _hasCachedComments ? Colors.blue[800] : null,
          ),
        ),
        subtitle: Text('$commentsコメント • $time'),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => widget.onRemove(widget.topic['id'] as int),
        ),
        onTap: () async {
          // 詳細へ遷移
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: widget.topic['id'] as int,
                title: title,
                commentCount: comments is int ? comments : int.tryParse('$comments') ?? 0,
              ),
            ),
          );
          // 戻ってきた直後に、まず自分を更新
          if (mounted) {
            await refreshCacheState();
            // 一覧全体にも更新要求（他タイルにも波及させる）
            widget.controller.refreshAll();
          }
        },
      ),
    );
  }
}

class NewListScreen extends StatefulWidget {
  const NewListScreen({super.key});

  @override
  State<NewListScreen> createState() => _NewListScreenState();
}

class _NewListScreenState extends State<NewListScreen>
    with WidgetsBindingObserver {
  static const String cacheKey = 'new_topics';

  final _controller = _TopicTileController();

  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// アプリがフォアグラウンドに戻ったタイミングでも全行を再評価
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAll();
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

  Future<void> _load() async {
    // まずキャッシュ
    logd('📂 [NewList._load] Loading topics from cache...', name: 'NewList');
    final cached = await CacheService.load(cacheKey);
    logd('📂 [NewList._load] Cached topics count: ${cached.length}', name: 'NewList');
    if (cached.length > 0) {
      logd('📂 [NewList._load] First topic ID: ${cached[0]['id']}', name: 'NewList');
    }
    if (cached.isNotEmpty) {
      setState(() {
        _topics = cached.cast<Map<String, dynamic>>();
        _loading = false;
      });
      logd('✅ [NewList._load] Loaded ${_topics.length} topics from cache', name: 'NewList');
    } else {
      logd('⚠️ [NewList._load] No cached topics, fetching from server...', name: 'NewList');
      await _fetchFromServer();
    }
  }

  Future<void> _fetchFromServer() async {
    try {
      logd('🌐 [NewList._fetchFromServer] Fetching new topics from server...', name: 'NewList');
      final uri = Uri.parse('${AppConfig.apiBase}/topics/new');
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as List<dynamic>;
      final list = data.cast<Map<String, dynamic>>();
      logd('🌐 [NewList._fetchFromServer] Fetched ${list.length} topics from server', name: 'NewList');
      if (list.isNotEmpty) {
        logd('🌐 [NewList._fetchFromServer] First topic from server - ID: ${list[0]['id']}, Title: ${list[0]['title']}', name: 'NewList');
      }
      await CacheService.save(cacheKey, list);
      logd('💾 [NewList._fetchFromServer] Saved ${list.length} topics to cache', name: 'NewList');

      if (!mounted) return;
      setState(() {
        _topics = list;
        _loading = false;
      });

      logd('🔄 [NewList._fetchFromServer] Refreshing all tiles (${_topics.length} items)...', name: 'NewList');
      // 新しい一覧が来たので、各タイルのキャッシュ表示も再評価
      _controller.refreshAll();
    } catch (e) {
      logd('❌ [NewList._fetchFromServer] Error fetching from server: $e', name: 'NewList');
      // API失敗時はキャッシュでできる限り表示
      final cached = await CacheService.load(cacheKey);
      logd('💾 [NewList._fetchFromServer] Falling back to cached topics: ${cached.length}', name: 'NewList');
      if (!mounted) return;
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
        }
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通信に失敗しました（キャッシュを使用）')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchFromServer,
      child: Scrollbar(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          itemCount: _topics.length,
          itemBuilder: (context, i) {
            final t = _topics[i];
            return _TopicTile(
              topic: t,
              controller: _controller,
              onRemove: _removeFromWatch,
            );
          },
        ),
      ),
    );
  }
}
