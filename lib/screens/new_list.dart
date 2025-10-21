// lib/screens/new_list.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../utils/platform_helper.dart';
import 'topic_detail.dart';

/// タイルを一括で再評価するための簡易コントローラ
class _TopicTileController {
  final Set<TopicTileState> _tiles = {};

  void register(TopicTileState tile) => _tiles.add(tile);
  void unregister(TopicTileState tile) => _tiles.remove(tile);

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
  final Function(int)? onRemove;

  const _TopicTile({
    required this.topic,
    required this.controller,
    this.onRemove,
  });

  @override
  State<_TopicTile> createState() => TopicTileState();
}

class TopicTileState extends State<_TopicTile> {
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

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => TopicDetailScreen(
              topicId: widget.topic['id'] as int,
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
                ? BorderSide(
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
                    width: 64,
                    height: 64,
                    child: (thumb != null && thumb.isNotEmpty)
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(CupertinoIcons.photo),
                          )
                        : const Icon(CupertinoIcons.photo),
                  ),
                ),
                if (_hasCachedComments)
                  Positioned(
                    top: -6,
                    right: -6,
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
                          fontSize: 15,
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
            if (widget.onRemove != null && _hasCachedComments)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: () => widget.onRemove!(widget.topic['id'] as int),
                child: const Icon(CupertinoIcons.xmark, color: CupertinoColors.destructiveRed),
              ),
          ],
        ),
      ),
    );
  }
}

class NewListScreen extends StatefulWidget {
  const NewListScreen({super.key});

  @override
  State<NewListScreen> createState() => NewListScreenState();
}

class NewListScreenState extends State<NewListScreen>
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
    PlatformHelper.showSnackBar(context, '履歴を削除しました');
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
      await fetchFromServer();
    }
  }

  Future<void> fetchFromServer() async {
    try {
      logd('🌐 [NewList.fetchFromServer] Fetching new topics from server...', name: 'NewList');
      final uri = Uri.parse('${AppConfig.apiBase}/topics/new');
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final data = jsonDecode(res.body) as List<dynamic>;
      final list = data.cast<Map<String, dynamic>>();
      logd('🌐 [NewList.fetchFromServer] Fetched ${list.length} topics from server', name: 'NewList');
      if (list.isNotEmpty) {
        logd('🌐 [NewList.fetchFromServer] First topic from server - ID: ${list[0]['id']}, Title: ${list[0]['title']}', name: 'NewList');
      }
      await CacheService.save(cacheKey, list);
      logd('💾 [NewList.fetchFromServer] Saved ${list.length} topics to cache', name: 'NewList');

      if (!mounted) return;
      setState(() {
        _topics = list;
        _loading = false;
      });

      logd('🔄 [NewList.fetchFromServer] Refreshing all tiles (${_topics.length} items)...', name: 'NewList');
      // 新しい一覧が来たので、各タイルのキャッシュ表示も再評価
      _controller.refreshAll();
    } catch (e) {
      logd('❌ [NewList.fetchFromServer] Error fetching from server: $e', name: 'NewList');
      // API失敗時はキャッシュでできる限り表示
      final cached = await CacheService.load(cacheKey);
      logd('💾 [NewList.fetchFromServer] Falling back to cached topics: ${cached.length}', name: 'NewList');
      if (!mounted) return;
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
        }
        _loading = false;
      });
      if (mounted) {
        PlatformHelper.showSnackBar(context, '通信に失敗しました（キャッシュを使用）');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: PlatformHelper.buildLoadingIndicator());
    }

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: fetchFromServer,
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final t = _topics[i];
              return _TopicTile(
                topic: t,
                controller: _controller,
                onRemove: _removeFromWatch,
              );
            },
            childCount: _topics.length,
          ),
        ),
      ],
    );
  }
}
