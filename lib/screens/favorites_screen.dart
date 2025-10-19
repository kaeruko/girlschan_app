import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../config/app_config.dart';
import '../utils/platform_helper.dart';
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
    PlatformHelper.showSnackBar(context, '履歴を削除しました');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      if (Platform.isMacOS) {
        return const Center(child: CupertinoActivityIndicator());
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (_watchedTopics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isMacOS ? CupertinoIcons.bookmark : Icons.bookmark_border,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            Text(
              '履歴に登録されたトピックはありません',
              style: TextStyle(
                fontSize: 16,
                color: Platform.isMacOS 
                    ? CupertinoColors.secondaryLabel 
                    : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'トピック詳細の📘をタップして登録',
              style: TextStyle(
                fontSize: 13,
                color: Platform.isMacOS 
                    ? CupertinoColors.tertiaryLabel 
                    : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (Platform.isMacOS) {
      return CustomScrollView(
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: _refreshWatched,
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final topic = _watchedTopics[i];
                return _FavoritesTile(
                  topic: topic,
                  onRemove: _removeFromWatch,
                  controller: _controller,
                );
              },
              childCount: _watchedTopics.length,
            ),
          ),
        ],
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
    if (mounted) {
      setState(() {
        _hasCachedComments = hasCached;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.topic['id'] as int;
    final title = widget.topic['title'] as String? ?? 'タイトル不明';
    final comments = widget.topic['comments'] as int? ?? 0;
    final time = widget.topic['time'] as String? ?? '';

    if (Platform.isMacOS) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: id,
                title: title,
                commentCount: comments,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: _hasCachedComments 
                ? CupertinoColors.systemBlue.withOpacity(0.1) 
                : CupertinoColors.white,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 14,
                        fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.w500,
                        color: _hasCachedComments ? CupertinoColors.systemBlue : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'コメント: $comments件 $time',
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: () => widget.onRemove(id),
                child: const Icon(CupertinoIcons.xmark, size: 18),
              ),
            ],
          ),
        ),
      );
    }

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
