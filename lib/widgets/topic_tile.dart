import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cache_service.dart';
import '../screens/topic_detail.dart';
import 'topic_tile_controller.dart';

/// 共通トピックタイル（Material 依存ナシ）
class TopicTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final TopicTileController controller;

  /// ×ボタンを表示するかどうか（親が制御）。
  final bool showRemoveButton;

  /// ×ボタン押下時のコールバック。意味付けは親に委ねる。
  final Future<void> Function(int topicId)? onRemove;

  /// true の場合、キャッシュがなくても × ボタンを表示する。
  /// false の場合はキャッシュ有無（コメントキャッシュ）と連動させる。
  final bool removeButtonAlwaysVisible;

  /// 詳細から戻った直後に呼ばれる（自分→全体の順で更新する前後に外側の再評価を差し込みたい時）
  final VoidCallback? onAfterPop;

  /// サムネイルの表示ON/OFF（お気に入りではナシ、一覧ではアリ等）
  final bool showThumb;

  const TopicTile({
    super.key,
    required this.topic,
    required this.controller,
    this.showRemoveButton = false,
    this.onRemove,
    this.removeButtonAlwaysVisible = false,
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
    refreshCacheState(); // 初回
  }

  @override
  void didUpdateWidget(covariant TopicTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldId = oldWidget.topic['id'] as int;
    final newId = widget.topic['id'] as int;
    if (oldId != newId) {
      setState(() {
        _hasCachedComments = false;
        _savedCommentNo = 0;
        _cacheModifiedTime = null;
      });
      // ignore: discarded_futures
      refreshCacheState();
    }
  }

  @override
  void dispose() {
    widget.controller.unregister(this);
    super.dispose();
  }

  @override
  Future<void> refreshCacheState() async {
    final id = widget.topic['id'] as int;

    final hasCached = await CacheService.exists('comments_$id');

    int saved = 0;
    DateTime? modifiedTime;
    int? cachedCount;

    if (hasCached) {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getInt('scroll_$id') ?? 0;
      // build() 内ではなくここで await
      modifiedTime = await CacheService.getModifiedTime('comments_$id');
      // ★キャッシュからコメント数を取得
      final cachedList = await CacheService.loadList('comments_$id');
      cachedCount = cachedList.length;
    }

    if (!mounted) return;
    setState(() {
      _hasCachedComments = hasCached;
      _savedCommentNo = saved;
      _cacheModifiedTime = modifiedTime;
      // ★キャッシュがあればwidget.topic['comments']も更新
      if (cachedCount != null && cachedCount > 0) {
        widget.topic['comments'] = cachedCount;
      }
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

  final showRemove = widget.showRemoveButton &&
    widget.onRemove != null &&
    (widget.removeButtonAlwaysVisible || _hasCachedComments);


    // ① 必ず初期化しておく（未初期化エラー対策）
    String commentDisplay = '$comments $posted_at';

    // ② ここで cacheTimeDisplay を定義・計算（この行より下で使えるスコープに置く）
    String cacheTimeDisplay = '';
    if (_cacheModifiedTime != null) {
      final now = DateTime.now();
      final diff = now.difference(_cacheModifiedTime!);
      if (diff.inMinutes < 1) {
        cacheTimeDisplay = '今';
      } else if (diff.inMinutes < 60) {
        cacheTimeDisplay = '${diff.inMinutes}分前';
      } else if (diff.inHours < 24) {
        cacheTimeDisplay = '${diff.inHours}時間前';
      } else {
        cacheTimeDisplay = '${_cacheModifiedTime!.month}/${_cacheModifiedTime!.day}';
      }
    }

    if (_hasCachedComments) {
      final total = comments;
      int shown = _savedCommentNo;

      if (shown > 0 && total > 0) {
        const pad = 2;
        shown = shown + pad;

        // total を超えないように＆マイナスにならないようにガード
        if (shown > total) shown = total;
        if (shown < 0) shown = 0;
      }

      final savedText = shown > 0 ? '$shown' : '0';
      commentDisplay = '$savedText/$total $posted_at';
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
                posted_at: posted_at ?? '',
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
                        _hasCachedComments && cacheTimeDisplay.isNotEmpty
                            ? 'コメント: $commentDisplay (キャッシュ: $cacheTimeDisplay)'
                            : 'コメント: $commentDisplay',
                        style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                ),
              ),
              // 右端 × ボタン（キャッシュあり時だけ）
              if (showRemove)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  onPressed: () async {
                    await widget.onRemove!(id);
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
