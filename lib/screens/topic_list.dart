// lib/screens/topic_list.dart
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../utils/platform_helper.dart';
import 'topic_detail.dart';

/// タイルを一括で再評価するための簡易コントローラ
class _TopicListTileController {
  final Set<TopicListTileState> _tiles = {};

  void register(TopicListTileState tile) => _tiles.add(tile);
  void unregister(TopicListTileState tile) => _tiles.remove(tile);

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
  State<TopicListScreen> createState() => TopicListScreenState();
}

class TopicListScreenState extends State<TopicListScreen>
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
      await fetchFromServer();
    }
  }

  Future<void> _removeFromWatch(int topicId) async {
    await removeWatchedTopicId(topicId);
    setState(() {
      _topics.removeWhere((topic) => topic['id'] == topicId);
    });
    // 全タイルを再評価して表示を更新
    _controller.refreshAll();
    PlatformHelper.showSnackBar(context, '履歴を削除しました');
  }

  Future<void> fetchFromServer() async {
    try {
      logd('🌐 [fetchFromServer] Fetching popular topics from server...', name: 'TopicList');
      final topics = await fetchPopularTopicsWithCache(); // API（api_service.dart）- 人気トピック用
      final list = topics.cast<Map<String, dynamic>>();
      logd('🌐 [fetchFromServer] Fetched ${list.length} topics from server', name: 'TopicList');
      if (list.isNotEmpty) {
        logd('🌐 [fetchFromServer] First topic from server: ${list[0]}', name: 'TopicList');
      }
      await CacheService.save(cacheKey, list);
      logd('💾 [fetchFromServer] Saved ${list.length} topics to cache', name: 'TopicList');

      if (!mounted) return;
      setState(() {
        _topics = list;
        _loading = false;
      });

      logd('🔄 [fetchFromServer] Refreshing all tiles...', name: 'TopicList');
      _controller.refreshAll();
    } catch (e) {
      logd('❌ [fetchFromServer] Error fetching from server: $e', name: 'TopicList');
      // 失敗時でもキャッシュがあれば出す
      final cached = await CacheService.load(cacheKey);
      logd('💾 [fetchFromServer] Falling back to cached topics: ${cached.length}', name: 'TopicList');
      if (!mounted) return;
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
        }
        _loading = false;
      });
      if (mounted) {
        PlatformHelper.showSnackBar(context, 'データの更新に失敗しました（キャッシュを使用）');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: fetchFromServer,
          ),
          if (_loading)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: PlatformHelper.buildLoadingIndicator(),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final topic = _topics[index];
                  return _TopicListTile(
                    topic: topic,
                    controller: _controller,
                    onRemove: _removeFromWatch,
                  );
                },
                childCount: _topics.length,
              ),
            ),
        ],
      ),
    );
  }
}

/// キャッシュがあるトピックを表示するカスタムタイル
class _TopicListTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final _TopicListTileController controller;
  final Function(int)? onRemove;

  const _TopicListTile({
    required this.topic,
    required this.controller,
    this.onRemove,
  });

  @override
  State<_TopicListTile> createState() => TopicListTileState();
}

class TopicListTileState extends State<_TopicListTile> {
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

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => TopicDetailScreen(
              topicId: id,
              title: title,
              commentCount: comments is int ? comments : int.tryParse('$comments') ?? 0,
            ),
          ),
        );
        if (mounted) {
          await refreshCacheState();
          widget.controller.refreshAll();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _hasCachedComments ? CupertinoColors.systemBlue.withOpacity(0.1) : CupertinoColors.white,
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator,
              width: 0.5,
            ),
            left: _hasCachedComments
                ? const BorderSide(
                    color: CupertinoColors.systemBlue,
                    width: 4,
                  )
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: (thumb != null && thumb.isNotEmpty)
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo, size: 30),
                          )
                        : const Icon(CupertinoIcons.photo, size: 30),
                  ),
                ),
                if (_hasCachedComments)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemBlue,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(CupertinoIcons.check_mark, color: CupertinoColors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.w500,
                          color: _hasCachedComments ? CupertinoColors.systemBlue : null,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$commentsコメント • $time',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                        ),
                  ),
                ],
              ),
            ),
            if (widget.onRemove != null)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => widget.onRemove!(id),
                child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.destructiveRed),
              ),
          ],
        ),
      ),
    );
  }
}
