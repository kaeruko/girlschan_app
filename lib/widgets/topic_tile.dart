import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // ★これを追加
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cache_service.dart';
import '../services/api_service.dart';
import '../screens/topic_detail.dart';
import '../utils/log.dart';
import 'topic_tile_controller.dart';
import '../services/settings_service.dart';

/// 共通トピックタイル（Material 依存ナシ）
class TopicTile extends StatefulWidget {
  final Map<String, dynamic> topic;
  final TopicTileController controller;

  /// ×ボタン押下時のコールバック。意味付けは親に委ねる。
  final Future<void> Function(int topicId)? onRemove;

  final Future<void> Function()? onAfterPop; // または FutureOr<void> Function()?

  /// サムネイルの表示ON/OFF（お気に入りではナシ、一覧ではアリ等）
  final bool showThumb;

  /// タップ時の挙動を親から指定できるようにする
  final Function(int topicId, String title, int comments, String postedAt)? onTopicTap;

  /// 新規タブで開く（Cmd+クリック / 中クリック）
  final Function(int topicId, String title, int comments, String postedAt)? onTopicNewTabTap;

  /// true にすると、キャッシュ有無に関わらず削除ボタンを常に表示する
  final bool alwaysShowRemove;

  const TopicTile({
    super.key,
    required this.topic,
    required this.controller,
    this.onRemove,
    this.onAfterPop,
    this.showThumb = true,
    this.onTopicTap,
    this.onTopicNewTabTap,
    this.alwaysShowRemove = false,
  });

  @override
  State<TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<TopicTile> implements TileRefreshable {
  bool _hasCachedComments = false;
  int _savedCommentNo = 0;
  DateTime? _cacheModifiedTime;
  bool _hasDraft = false; // ★ 下書き状態を管理
  bool _isLoading = false; // ★ 読み込み中の状態を管理
  final _settings = SettingsService();


  @override
  int get topicId => widget.topic['id'] as int;

  @override
  void initState() {
    super.initState();
    widget.controller.register(this);
    _settings.addListener(_onSettingsChanged);
    refreshCacheState(); // 初回
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
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
        _hasDraft = false; // ★ 下書き状態もリセット
      });
      // ignore: discarded_futures
      refreshCacheState();
    } else {
      // 同じIDでもコメント数等のデータが変わった場合はキャッシュを再取得
      final oldComments = '${oldWidget.topic['comments']}';
      final newComments = '${widget.topic['comments']}';
      if (oldComments != newComments) {
        // ignore: discarded_futures
        refreshCacheState();
      }
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    widget.controller.unregister(this);

    super.dispose();
  }

  @override
  Future<void> refreshCacheState() async {
    final id = widget.topic['id'] as int;
    try {
      // final meta = await CacheService.loadMap('topic_meta_$id');
      final meta = await getTopicMetaFromDb(id);
      if (meta != null) {
        if (mounted) {
          setState(() {
            // メタデータにコメント数があれば上書き
            if (meta['total'] != null) {
              widget.topic['comments'] = meta['total'];
            }
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
    // final hasCached = await CacheService.exists('comments_$id');
    final hasCached = await hasCachedCommentsInDb(id);
    
    // ★ デバッグログ追加 (Step 30)
    // logd('🔍 [TopicTile] refreshCacheState id=$id, hasCached=$hasCached');

    int saved = 0;
    DateTime? modifiedTime;

    if (hasCached) {
      final prefs = await CacheService.getPrefs();
      saved = prefs.getInt('scroll_$id') ?? 0;
      // modifiedTime = await CacheService.getModifiedTime('comments_$id');
      modifiedTime = await getTopicFetchedAt(id);
    }

    // ★ 3. 下書きの存在確認
    // ファイル書き込みの遅延を考慮して少し待つ
    await Future.delayed(const Duration(milliseconds: 100));
    final hasDraft = await CacheService.hasDraft(id);

    if (!mounted) return;
    setState(() {
      _hasCachedComments = hasCached;
      _savedCommentNo = saved;
      _cacheModifiedTime = modifiedTime;
      _hasDraft = hasDraft; // ★ 下書き状態を更新
    });
    
    // ★ デバッグログ (確定後)
    // if (!hasCached) {
    //    logd('⚠️ [TopicTile] Cache missing for ID=$id. _hasCachedComments=false');
    // }
    
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.topic['id'] as int;
    var title = widget.topic['title'] as String? ?? '';
    if (title.isEmpty) title = 'タイトル不明';
    final comments = widget.topic['comments'] is int
        ? widget.topic['comments'] as int
        : int.tryParse('${widget.topic['comments']}') ?? 0;
    final postedAt = (widget.topic['posted_at'] as String? ?? '').replaceAllMapped(
        RegExp(r'(\d{1,2}:\d{2}):\d{2}'), (match) => match.group(1)!);
    final thumb = widget.topic['thumb'] as String?;

    // 表示用データの計算
    final displayData = _calculateDisplayData(comments, postedAt);
    final bgColor = _calculateBackgroundColor(displayData.isOld);

    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kMiddleMouseButton) {
          widget.onTopicNewTabTap?.call(id, title, comments, postedAt);
        }
      },
      child: Material(
      color: bgColor,
      child: InkWell(
        onTap: () => _handleTap(context, id, title, comments, postedAt),
        hoverColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            border: _hasCachedComments
                ? const Border(left: BorderSide(color: CupertinoColors.systemBlue, width: 4))
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // サムネイル部分
              if (widget.showThumb) ...[
                _buildThumbnail(thumb),
                const SizedBox(width: 12),
              ],
              // トピック情報
              Expanded(
                child: _buildTopicInfo(
                  title,
                  displayData.isBold,
                  displayData.isOld,
                  displayData.commentDisplay,
                  displayData.cacheTimeDisplay,
                ),
              ),
              // 削除ボタン
              if (widget.onRemove != null && (_hasCachedComments || widget.alwaysShowRemove)) _buildRemoveButton(id),
              // ★ 読み込み中インジケーター
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: CupertinoActivityIndicator(radius: 10),
                ),
            ],
          ),
        ),
      ),
      ), // Material
    ); // Listener
  }

  /// サムネイル部分のWidget
  Widget _buildThumbnail(String? thumbUrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 60,
            height: 60,
            child: (thumbUrl != null && thumbUrl.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: thumbUrl,
                    httpHeaders: const {'Referer': 'https://girlschannel.net/'},
                    memCacheWidth: 120, // 60 * 2 (Retina考慮)
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(
                      CupertinoIcons.photo,
                      size: 28,
                      color: CupertinoColors.systemGrey,
                    ),
                    errorWidget: (context, url, error) => const Icon(
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
            child: _buildBadge(CupertinoIcons.check_mark, CupertinoColors.activeBlue),
          ),
        if (_hasDraft)
          Positioned(
            bottom: -4,
            right: -4,
            child: _buildBadge(CupertinoIcons.pencil, CupertinoColors.systemOrange, size: 14),
          ),
      ],
    );
  }

  /// バッジWidget（チェックマーク、鉛筆マークなど）
  Widget _buildBadge(IconData icon, Color color, {double size = 16}) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      padding: const EdgeInsets.all(4),
      child: Icon(icon, color: CupertinoColors.white, size: size),
    );
  }

  /// トピック情報部分のWidget
  Widget _buildTopicInfo(
    String title,
    bool isBold,
    bool isOld,
    String commentDisplay,
    String cacheTimeDisplay,
  ) {
    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title),
                if (!widget.showThumb && _hasDraft)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _buildBadge(CupertinoIcons.pencil, CupertinoColors.systemOrange, size: 10),
                    ),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              // 太字になるのは「dat落ちではなく(生きてて)」かつ「未読」のときだけ
              fontWeight: (!isOld && isBold) ? FontWeight.w800 : FontWeight.w400,
              // dat落ちならグレー、それ以外は青
              color: isOld ? CupertinoColors.systemGrey : CupertinoColors.activeBlue,
              fontSize: _settings.fontSize,
            ),

          ),
          const SizedBox(height: 4),
          Text(
            _hasCachedComments && cacheTimeDisplay.isNotEmpty
                // ? 'コメント: $commentDisplay (キャッシュ: $cacheTimeDisplay)'
                ? 'コメント: $commentDisplay'
                : 'コメント: $commentDisplay',
            style: TextStyle(fontSize: _settings.fontSize - 2, color: CupertinoColors.systemGrey),

          ),
        ],
      ),
    );
  }

  /// 削除ボタンWidget
  Widget _buildRemoveButton(int id) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(28, 28),
      onPressed: () async {
        logd('🗑️ [TopicTile] Remove button pressed: ID=$id');
        logd('🗑️ [TopicTile] onRemove callback exists: ${widget.onRemove != null}');
        if (widget.onRemove != null) {
          logd('🗑️ [TopicTile] Calling onRemove callback...');
          await widget.onRemove!(id);
          logd('🗑️ [TopicTile] onRemove callback completed');
        }
        if (mounted) {
          logd('🗑️ [TopicTile] Calling refreshCacheState...');
          await refreshCacheState();
          logd('🗑️ [TopicTile] refreshCacheState completed');
        }
        logd('🗑️ [TopicTile] Calling controller.refreshAll...');
        await widget.controller.refreshAll();
        logd('🗑️ [TopicTile] controller.refreshAll completed');
      },
      child: const Icon(CupertinoIcons.xmark, size: 20),
    );
  }

  /// タップ処理
  Future<void> _handleTap(
    BuildContext context,
    int id,
    String title,
    int comments,
    String postedAt,
  ) async {
    // 既に既読キャッシュがない場合はローディング開始
    bool startLoading = !_hasCachedComments;
    if (startLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // ポーリング処理をバックグラウンドで開始
    Future<void> pollForCache() async {
      int attempts = 0;
      while (attempts < 20) { // 最大10秒 (500ms * 20)
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        
        final hasCached = await hasCachedCommentsInDb(id);
        if (hasCached) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            await refreshCacheState();
          }
          return;
        }
        attempts++;
      }
      // タイムアウト
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    if (startLoading) {
      pollForCache(); // awaitせず非同期で走らせる
    }


    // Cmd+クリック (macOS) / Ctrl+クリック (Windows) → 新規タブで開く
    if (widget.onTopicNewTabTap != null) {
      final isMeta = HardwareKeyboard.instance.isMetaPressed;
      final isCtrl = HardwareKeyboard.instance.isControlPressed;
      if (isMeta || isCtrl) {
        widget.onTopicNewTabTap!(id, title, comments, postedAt);
        if (mounted) await refreshCacheState();
        return;
      }
    }

    // ★追加: 親から挙動が指定されていればそちらを優先実行
    if (widget.onTopicTap != null) {
      widget.onTopicTap!(id, title, comments, postedAt);
    } else {

      logd('👆 [TopicTile] Tap detected: ID=$id', name: 'TileNav');

      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => TopicDetailScreen(
            topicId: id,
            title: title,
            commentCount: comments,
            postedAt: postedAt,
          ),
        ),
      );

      logd('🔙 [TopicTile] Returned from Detail: ID=$id', name: 'TileNav');

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

    }
    
    // Navigator から戻った、もしくは直接タップ直後にも念の為リフレッシュ
    if (mounted) await refreshCacheState();
  }

  /// 表示データの計算
  _DisplayData _calculateDisplayData(int comments, String postedAt) {
    String commentDisplay = '$comments $postedAt';
    String cacheTimeDisplay = '';
    bool isBold = false;
    bool isOld = false;

    // キャッシュ時刻の表示計算
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
        cacheTimeDisplay = '${_cacheModifiedTime!.year}/${_cacheModifiedTime!.month}/${_cacheModifiedTime!.day}';
      }
    }

    // キャッシュがある場合の表示計算
    if (_hasCachedComments) {
      final total = comments;
      int shown = _savedCommentNo;

      if (shown > 0 && total > 0) {
        const pad = 6;
        shown = shown + pad;
        if (shown > total) shown = total;
        if (shown < 0) shown = 0;
      }

      final savedText = shown > 0 ? '$shown' : '0';
      commentDisplay = '$savedText/$total $postedAt';

      // 未読がある場合は太字
      if (shown < total) {
        isBold = true;
      }
    }

    // 1ヶ月以上前かどうか判定
    if (postedAt.isNotEmpty) {
      final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(postedAt);
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

    return _DisplayData(
      commentDisplay: commentDisplay,
      cacheTimeDisplay: cacheTimeDisplay,
      isBold: isBold,
      isOld: isOld,
    );
  }

  /// 背景色の計算
  Color _calculateBackgroundColor(bool isOld) {
    if (_hasCachedComments) {
      if (isOld) {
        return CupertinoColors.systemGrey6;
      } else {
        return CupertinoColors.systemBlue.withValues(alpha: 0.05);
      }
    } else {
      return CupertinoColors.transparent;
    }
  }
}

/// 表示データを保持するクラス
class _DisplayData {
  final String commentDisplay;
  final String cacheTimeDisplay;
  final bool isBold;
  final bool isOld;

  _DisplayData({
    required this.commentDisplay,
    required this.cacheTimeDisplay,
    required this.isBold,
    required this.isOld,
  });
}
