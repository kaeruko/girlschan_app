// topic_tile.dart (Cupertino版)

import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cache_service.dart';
import '../utils/log.dart';
import '../screens/topic_detail.dart';
import 'topic_tile_controller.dart';

/// 共通トピックタイル（Cupertino）
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

    final theme = CupertinoTheme.of(context);
    final titleStyle = theme.textTheme.textStyle.copyWith(
      fontSize: 14,
      fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.w500,
      color: _hasCachedComments
          ? CupertinoColors.activeBlue.resolveFrom(context)
          : theme.textTheme.textStyle.color,
    );
    final subStyle = theme.textTheme.textStyle.copyWith(
      fontSize: 12,
      color: CupertinoColors.systemGrey.resolveFrom(context),
    );

    return Container(
      decoration: BoxDecoration(
        color: _hasCachedComments
            ? CupertinoColors.activeBlue.resolveFrom(context).withOpacity(0.05)
            : CupertinoColors.transparent,
        border: _hasCachedComments
            ? Border(
                left: BorderSide(
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                  width: 4,
                ),
              )
            : null,
      ),
      child: _CupertinoTile(
        leading: widget.showThumb
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: (thumb != null && thumb.isNotEmpty)
                        ? Image.network(
                            thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              CupertinoIcons.photo,
                              size: 28,
                              color: CupertinoColors.systemGrey.resolveFrom(context),
                            ),
                          )
                        : Icon(
                            CupertinoIcons.photo,
                            size: 28,
                            color: CupertinoColors.systemGrey.resolveFrom(context),
                          ),
                  ),
                  if (_hasCachedComments)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeBlue.resolveFrom(context),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          CupertinoIcons.check_mark_circled_solid,
                          color: CupertinoColors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              )
            : null,
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        subtitle: Text(
          'コメント: $commentDisplay $time',
          style: subStyle,
        ),
        trailing: (_hasCachedComments && widget.onRemoveIfCached != null)
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () async {
                  await widget.onRemoveIfCached!(id);
                  if (mounted) await refreshCacheState();   // 自分の再評価
                  await widget.controller.refreshAll();      // 全体再評価
                },
                child: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
              )
            : null,
        onTap: () async {
          await Navigator.push(
            context,
            CupertinoPageRoute(
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

/// シンプルなCupertino版タイル（ListTile代替）
class _CupertinoTile extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _CupertinoTile({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = CupertinoColors.systemGrey4.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
