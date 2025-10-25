import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cache_service.dart';
import '../screens/topic_detail.dart';
import 'topic_tile_controller.dart';

/// 共通トピックタイル（Material 依存ナシ）
class TopicTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final TopicTileController controller;

  /// キャッシュ（`comments_<id>`）があるときだけ × ボタンを表示して削除可能にする
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
  int _savedCommentNo = 0;
  DateTime? _cacheModifiedTime;

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
    // logd('🔍 [TopicTile.refreshCacheState] id=$id', name: 'TopicTile');

    final hasCached = await CacheService.exists('comments_$id');

    int saved = 0;
    DateTime? modifiedTime;
    
    if (hasCached) {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getInt('scroll_$id') ?? 0;
      // キャッシュ作成日時を取得
      modifiedTime = await CacheService.getModifiedTime('comments_$id');
    }

    if (!mounted) return;
    setState(() {
      _hasCachedComments = hasCached;
      _savedCommentNo = saved;
      _cacheModifiedTime = modifiedTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.topic['id'] as int;
    final title = widget.topic['title'] as String? ?? 'タイトル不明';
    final comments = widget.topic['comments'] is int
        ? widget.topic['comments'] as int
        : int.tryParse('${widget.topic['comments']}') ?? 0;
    final posted_at = widget.topic['posted_at'] as String? ?? '';
    final thumb = widget.topic['thumb'] as String?;

    final commentDisplay = _hasCachedComments
        ? '${_savedCommentNo > 0 ? '$_savedCommentNo' : ''}/$comments $posted_at'
        : '$comments件';

    // キャッシュ作成日時のフォーマット
    String cacheTimeDisplay = '';
    if (_cacheModifiedTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_cacheModifiedTime!);
      
      if (diff.inMinutes < 1) {
        cacheTimeDisplay = '今';
      } else if (diff.inHours < 1) {
        cacheTimeDisplay = '${diff.inMinutes}分前';
      } else if (diff.inDays < 1) {
        cacheTimeDisplay = '${diff.inHours}時間前';
      } else if (diff.inDays == 1) {
        cacheTimeDisplay = '昨日';
      } else if (diff.inDays < 7) {
        cacheTimeDisplay = '${diff.inDays}日前';
      } else {
        // それ以上古い場合は日付で表示
        cacheTimeDisplay = '${_cacheModifiedTime!.month}/${_cacheModifiedTime!.day}';
      }
    }

    final blue = CupertinoColors.systemBlue;

    return Container(
      decoration: BoxDecoration(
        color: _hasCachedComments ? blue.withOpacity(0.05) : CupertinoColors.transparent,
        border: _hasCachedComments
            ? Border(left: BorderSide(color: blue, width: 4))
            : null,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: id,
                title: title,
                commentCount: comments,
              ),
            ),
          );
          // 外側フック → 自分更新 → 全体更新（順）
          widget.onAfterPop?.call();
          if (mounted) await refreshCacheState();
          await widget.controller.refreshAll();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.showThumb)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: (thumb != null && thumb.isNotEmpty)
                            ? Image.network(
                                thumb,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  CupertinoIcons.photo,
                                  size: 28,
                                  color: CupertinoColors.systemGrey,
                                ),
                              )
                            : const Icon(
                                CupertinoIcons.photo,
                                size: 28,
                                color: CupertinoColors.systemGrey,
                              ),
                      ),
                    ),
                    if (_hasCachedComments)
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: CupertinoColors.activeBlue,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            CupertinoIcons.check_mark,
                            color: CupertinoColors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              if (widget.showThumb) const SizedBox(width: 12),
              // タイトル + サブ
              Expanded(
                child: DefaultTextStyle(
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.w500,
                          color: _hasCachedComments ? CupertinoColors.activeBlue : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'コメント: $commentDisplay ${_hasCachedComments && cacheTimeDisplay.isNotEmpty ? '(キャッシュ: $cacheTimeDisplay)' : ''}',
                        style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                ),
              ),
              // 右端 × ボタン（キャッシュあり時だけ）
              if (_hasCachedComments && widget.onRemoveIfCached != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  onPressed: () async {
                    await widget.onRemoveIfCached!(id);
                    if (mounted) await refreshCacheState();
                    await widget.controller.refreshAll();
                  },
                  child: const Icon(CupertinoIcons.xmark, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
