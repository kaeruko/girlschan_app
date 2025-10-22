import 'topic_tile_controller.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../screens/topic_detail.dart';
import 'topic_tile_controller.dart';

/// 共通トピックタイル
class TopicTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final TopicTileController controller;

  /// キャッシュ（comments_<id>）があるときだけ × ボタンを表示して削除可能にする
  final Future<void> Function(int topicId)? onRemoveIfCached;

  /// 詳細から戻った直後に呼ばれる（自分→全体の順で更新する前後に外側の再評価を差し込みたい時）
  final VoidCallback? onAfterPop;

  /// サムネイルの表示ON/OFF（お気に入りではナシ、一覧ではアリ等）
  final bool showThumb;

  const TopicTile({
    super.key,
    required this.topic,
    required this.controller,
    this.onRemoveIfCached,
    this.onAfterPop,
    this.showThumb = true,
  });

  @override
  State<TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<TopicTile> implements TileRefreshable {
  bool _hasCachedComments = false;
  int _cachedCommentCount = 0;
  int _savedCommentNo = 0;

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

  @override
  Future<void> refreshCacheState() async {
    final id = widget.topic['id'] as int;
    logd('🔍 [TopicTile.refreshCacheState] id=$id', name: 'TopicTile');

    final hasCached = await CacheService.exists('comments_$id');

    int cached = 0;
    int saved = 0;
    if (hasCached) {
      final prefs = await SharedPreferences.getInstance();
      cached = prefs.getInt('synced_$id') ?? 0;
      saved  = prefs.getInt('scroll_$id') ?? 0;
    }

    if (!mounted) return;
    setState(() {
      _hasCachedComments = hasCached;
      _cachedCommentCount = cached;
      _savedCommentNo = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.topic['id'] as int;
    final title = widget.topic['title'] as String? ?? 'タイトル不明';
    final comments = widget.topic['comments'] is int
        ? widget.topic['comments'] as int
        : int.tryParse('${widget.topic['comments']}') ?? 0;
    final time = widget.topic['time'] as String? ?? '';
    final thumb = widget.topic['thumb'] as String?;

    final commentDisplay = _hasCachedComments
        ? '${_savedCommentNo > 0 ? '$_savedCommentNo' : ''}/$comments件'
        : '$comments件';

    return Container(
      decoration: BoxDecoration(
        color: _hasCachedComments ? Colors.blue.withOpacity(0.05) : Colors.transparent,
        border: _hasCachedComments
            ? const Border(
                left: BorderSide(color: Colors.blue, width: 4),
              )
            : null,
      ),
      child: ListTile(
        leading: widget.showThumb
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 60, height: 60,
                    child: (thumb != null && thumb.isNotEmpty)
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_not_supported, size: 30, color: Colors.grey),
                          )
                        : const Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                  ),
                  if (_hasCachedComments)
                    Positioned(
                      top: -8, right: -8,
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              )
            : null,
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
        trailing: (_hasCachedComments && widget.onRemoveIfCached != null)
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  await widget.onRemoveIfCached!(id);
                  // 外側でキャッシュ削除したので自分＆全体の再評価
                  if (mounted) await refreshCacheState();
                  await widget.controller.refreshAll();
                },
              )
            : null,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: id,
                title: title,
                commentCount: comments,
              ),
            ),
          );
          // 外側フック → 自分更新 → 全体更新（順に実施）
          widget.onAfterPop?.call();
          if (mounted) await refreshCacheState();
          await widget.controller.refreshAll();
        },
      ),
    );
  }
}
