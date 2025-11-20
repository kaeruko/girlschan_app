import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../services/cache_service.dart';
import '../screens/topic_detail.dart';
import '../utils/log.dart';
import 'topic_tile_controller.dart';

/// 共通トピックタイル（Material 依存ナシ）
class TopicTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final TopicTileController controller;

  /// ×ボタン押下時のコールバック。意味付けは親に委ねる。
  final Future<void> Function(int topicId)? onRemove;

  final Future<void> Function()? onAfterPop; // または FutureOr<void> Function()?

  /// サムネイルの表示ON/OFF（お気に入りではナシ、一覧ではアリ等）
  final bool showThumb;

  const TopicTile({
    super.key,
    required this.topic,
    required this.controller,
    this.onRemove,
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
    try {
      final meta = await CacheService.loadMap('topic_meta_$id');
      if (meta != null) {
        if (mounted) {
          setState(() {
            // メタデータに日時があれば上書き
            if (meta['posted_at'] != null && meta['posted_at'].toString().isNotEmpty) {
              widget.topic['posted_at'] = meta['posted_at'];
            }
            // メタデータにサムネがあれば上書き
            if (meta['thumb'] != null && meta['thumb'].toString().isNotEmpty) {
              widget.topic['thumb'] = meta['thumb'];
            }
          });
        }
      }
    } catch (e) {
      // エラーは無視
    }

    // 2. コメントキャッシュ（既読状態）の確認（既存の処理）
    final hasCached = await CacheService.exists('comments_$id');

    int saved = 0;
    DateTime? modifiedTime;
    int? cachedCount;

    if (hasCached) {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getInt('scroll_$id') ?? 0;
      modifiedTime = await CacheService.getModifiedTime('comments_$id');
      
      // リスト長を取得（コメント数バッジ用）
      final cachedList = await CacheService.loadList('comments_$id');
      cachedCount = cachedList.length;
    }

    if (!mounted) return;
    setState(() {
      _hasCachedComments = hasCached;
      _savedCommentNo = saved;
      _cacheModifiedTime = modifiedTime;
      
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

    final showRemove = widget.onRemove != null;


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

    bool isBold = false;
    if (_hasCachedComments) {
      final total = comments;
      int shown = _savedCommentNo;

      if (shown > 0 && total > 0) {
        const pad = 4;
        shown = shown + pad;
        if (shown > total) shown = total;
        if (shown < 0) shown = 0;
      }

      final savedText = shown > 0 ? '$shown' : '0';
      commentDisplay = '$savedText/$total $posted_at';
      
      // ★ 未読がある場合（表示済み < 総数）は太字にする
      if (shown < total) {
        isBold = true;
      }
    }

    final blue = CupertinoColors.systemBlue;
    
    // ★ 1ヶ月以上前かどうか判定
    bool isOld = false;
    if (posted_at.isNotEmpty) {
      // "2025/11/19(水) 20:28" 形式を想定
      final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(posted_at);
      if (m != null) {
        final y = int.parse(m.group(1)!);
        final mo = int.parse(m.group(2)!);
        final d = int.parse(m.group(3)!);
        final date = DateTime(y, mo, d);
        final diff = DateTime.now().difference(date).inDays;
        if (diff > 30) {
          isOld = true;
        }
      }
    }

    // 背景色の決定
    Color? bgColor;
    if (_hasCachedComments) {
      if (isOld) {
        // 既読かつ古い -> グレー（少し濃いめにする）
        bgColor = CupertinoColors.systemGrey6;
      } else {
        // 既読かつ新しい -> 青
        bgColor = blue.withOpacity(0.05);
      }
    } else {
      // 未読 -> 透明（古くても透明）
      bgColor = CupertinoColors.transparent;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: _hasCachedComments
            ? Border(left: BorderSide(color: blue, width: 4))
            : null,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          // ① まず“今このタイルに紐づいている”コールバックを確保（ここが重要）
          final afterPop = widget.onAfterPop;

          logd('👆 [TopicTile] Tap detected: ID=${widget.topic['id']}', name: 'TileNav');

          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: id,
                title: title,
                commentCount: comments,
                posted_at: posted_at,
              ),
            ),
          );

          logd('🔙 [TopicTile] Returned from Detail: ID=${widget.topic['id']}', name: 'TileNav');

          // ② “キャプチャ済み” のコールバックを呼ぶ（await してOK）
          final cb = widget.onAfterPop;
          if (cb != null) {
            logd('📞 [TopicTile] Calling onAfterPop hash=${identityHashCode(cb)}', name: 'TileNav');
            try {
              await cb();
              logd('✅ [TopicTile] onAfterPop completed hash=${identityHashCode(cb)}', name: 'TileNav');
            } catch (e, st) {
              logd('❌ [TopicTile] onAfterPop error: $e\n$st', name: 'TileNav');
            }
          } else {
            logd('⚠️ [TopicTile] onAfterPop is NULL', name: 'TileNav');
          }

          if (mounted) await refreshCacheState();
          // await widget.controller.refreshAll(); // 親でやっているなら不要のままでOK
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
                                headers: const {'Referer': 'https://girlschannel.net/'},
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
                          fontWeight: (isBold && !isOld) ? FontWeight.w800 : FontWeight.w400,
                          color: (!isOld) ? CupertinoColors.activeBlue : null,
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
