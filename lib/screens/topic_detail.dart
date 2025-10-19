import 'dart:convert';
import 'dart:math' as math; // ★ 修正: max 用
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import 'comment_post_webview.dart';

class TopicDetailScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  List<dynamic> _allComments = [];            // サーバ同期済み + ローカル投稿を含む最新の「表示用」ソース
  List<dynamic> _displayedComments = [];      // 互換のため保持（= 常に _allComments と同じにする） // ★ 修正
  bool _loading = true;
  bool _loadingMore = false;
  bool _isWatched = false;
  bool _hasMoreComments = true;
  int _totalComments = 0;
  bool _bottomCheckInFlight = false;
  DateTime _lastBottomCheck = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _bottomCheckCooldown = Duration(seconds: 2);

  static const int _commentsPerPage = 10;
  final ScrollController _scrollController = ScrollController();
  double _savedOffset = 0.0;
  Set<int> _clippedCommentNos = {};
  // ★ 追加: 復元のための保存値
  int _savedSyncedCount = 0;      // 保存しておいた「サーバ同期済み件数」
  bool _needsDeferredRestore = false; // 差分取得後に再ジャンプが必要か

  @override
  void initState() {
    super.initState();
    logd('initState: topicId=${widget.topicId}, title=${widget.title}');
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================
  // ユーティリティ
  // =========================================

  // 「サーバ同期済み」件数（ローカル投稿は除外） // ★ 修正
  int _serverSyncedCount() => _allComments.where((c) => c['isLocal'] != true).length;

  // スクロール復元 // ★ 修正
  void _restoreScrollAfterBuild() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      final jump = _savedOffset.clamp(0.0, max);
      if (jump > 0) {
        _scrollController.jumpTo(jump);
      }
    });
  }

  // =========================================
  // スクロール検知（追加読み込み）
  // =========================================
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final max = _scrollController.position.maxScrollExtent;
    final cur = _scrollController.offset;
    final remain = max - cur;
    logd('_onScroll: cur=$cur max=$max remain=$remain loadingMore=$_loadingMore hasMore=$_hasMoreComments');

    // 通常ページネーション
    if (remain < 300 && !_loadingMore && _hasMoreComments) {
      logd('_onScroll: near bottom → load more');
      _loadMoreComments();
      return;
    }

    // 末尾張り付きで hasMore=false の“つつき”（連打防止）
    if (remain <= 0 && !_loadingMore && !_hasMoreComments && !_bottomCheckInFlight) {
      final now = DateTime.now();
      if (now.difference(_lastBottomCheck) >= _bottomCheckCooldown) {
        _lastBottomCheck = now;
        _bottomCheckInFlight = true;
        logd('_onScroll: at end & no-more → delta check');
        _fetchDeltaFromServer().whenComplete(() {
          _bottomCheckInFlight = false;
        });
      }
    }
  }


  // =========================================
  // 最後のコメント到達後の下スワイプ検知
  // =========================================
  void _onOverscrollBottom() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    final remain = maxScroll - current;

    logd('_onOverscrollBottom: cur=$current max=$maxScroll remain=$remain loadingMore=$_loadingMore hasMore=$_hasMoreComments');

    // Case A: 通常ページネーション
    if (remain < 50 && !_loadingMore && _hasMoreComments) {
      logd('_onOverscrollBottom: paginate → load more');
      _loadMoreComments();
      return;
    }

    // Case B: 末尾に張り付いていて hasMore=false → 新着確認だけ叩く（クールダウン付き）
    if (remain <= 0 && !_loadingMore && !_hasMoreComments && !_bottomCheckInFlight) {
      final now = DateTime.now();
      if (now.difference(_lastBottomCheck) < _bottomCheckCooldown) {
        return; // 連打防止
      }
      _lastBottomCheck = now;
      _bottomCheckInFlight = true;
      logd('_onOverscrollBottom: no-more but at end → delta check');
      _fetchDeltaFromServer().whenComplete(() {
        _bottomCheckInFlight = false;
      });
    }
  }


  // =========================================
  // 差分取得（サーバから offset 以降を取ってマージ） // ★ 修正: 新規
  // =========================================
// 差分取得（サーバから offset 以降を取ってマージ）
Future<void> _fetchDeltaFromServer({int? overrideOffset}) async {
  if (_loadingMore) return;
  setState(() => _loadingMore = true);

  try {
    final offset = overrideOffset ?? _serverSyncedCount();

    // ← api_service を使う
    final page = await fetchCommentsWithPagination(
      widget.topicId,
      offset: offset,
      limit: _commentsPerPage,
    );

    final newComments = (page['comments'] as List<dynamic>? ?? []);
    final total = (page['total'] as int?) ?? _totalComments;

    final existingRemote = _allComments.where((c) => c['isLocal'] != true).toList();
    final mergedRemote  = _mergeComments(existingRemote, newComments);
    final locals        = _allComments.where((c) => c['isLocal'] == true).toList();

    setState(() {
      _totalComments  = total;
      _allComments    = [...mergedRemote, ...locals];
      _displayedComments = List.of(_allComments);
      _hasMoreComments = mergedRemote.length < total;
    });

    await CacheService.save('comments_${widget.topicId}', mergedRemote);

    // 復元待ち && 目標件数に到達したらもう一度 jump
    if (_needsDeferredRestore && _serverSyncedCount() >= _savedSyncedCount) {
      _needsDeferredRestore = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final max = _scrollController.position.maxScrollExtent;
          final jump = _savedOffset.clamp(0.0, max);
          _scrollController.jumpTo(jump);
        }
      });
    }
  } catch (e) {
    debugPrint('❌ 差分取得エラー: $e');
  } finally {
    if (mounted) setState(() => _loadingMore = false);
  }
}



  // =========================================
  // 追加コメント読み込み（スクロール末尾） // ★ 修正: 差分取得を使う
  // =========================================
  Future<void> _loadMoreComments() async {
    await _fetchDeltaFromServer();
  }

  // =========================================
  // スクロール位置保存
  // =========================================
  Future<void> _saveScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (_scrollController.hasClients) {
      await prefs.setDouble('scroll_${widget.topicId}', _scrollController.offset);
      await prefs.setInt('synced_${widget.topicId}', _serverSyncedCount()); // ★ 追加
    }
  }

  Future<void> _loadScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    _savedOffset = prefs.getDouble('scroll_${widget.topicId}') ?? 0.0;
    _savedSyncedCount = prefs.getInt('synced_${widget.topicId}') ?? 0; // ★ 追加
  }

  // ★ 追加: 保存していた同期件数まで取り切ってからオフセット復元
  Future<void> _ensureSyncedToSavedAndRestore() async {
    // 目標件数が無ければ通常復元だけ
    final current = _serverSyncedCount();
    if (_savedSyncedCount <= 0 || current >= _savedSyncedCount) {
      _restoreScrollAfterBuild();
      return;
    }

    // まだ足りない → 差分を取り切る（10件ずつでもOK）
    _needsDeferredRestore = true; // 差分完了後に再ジャンプさせる
    while (_serverSyncedCount() < _savedSyncedCount && _hasMoreComments) {
      await _fetchDeltaFromServer();
    }

    // 取り切れたら（あるいは total が縮んでこれ以上増えないなら）復元
    _restoreScrollAfterBuild();
  }



  // =========================================
  // ローカル投稿
  // =========================================
  Future<void> _saveLocalComment(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_comments_${widget.topicId}';
    final existing = prefs.getStringList(key) ?? [];

    // 既存の no の最大値 + 1 を割り当て（サーバ同期済みの続きとして表示） // ★ 修正
    int maxNo = 0;
    for (final c in _allComments) {
      final n = (c['no'] as int?) ?? 0;
      if (n > maxNo) maxNo = n;
    }

    final newComment = {
      'no': maxNo + 1,
      'body': text,
      'time': DateTime.now().toString().substring(0, 19),
      'plus': 0,
      'minus': 0,
      'name': '自分（投稿済）',
      'isLocal': true, // ★ 修正: ローカルフラグ
    };

    existing.add(jsonEncode(newComment));
    await prefs.setStringList(key, existing);

    setState(() {
      _allComments.add(newComment);
      _displayedComments = List.of(_allComments); // ★ 修正
    });
  }

  Future<List<Map<String, dynamic>>> _loadLocalComments() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_comments_${widget.topicId}';
    final stored = prefs.getStringList(key) ?? [];
    final list = stored.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    // 読み出し時にも isLocal を立てておく // ★ 修正
    for (final c in list) {
      c['isLocal'] = true;
    }
    return list;
  }

  // =========================================
  // Pull to refresh（差分同期に変更） // ★ 修正
  // =========================================
  Future<void> fetchComments() async {
    logd('Pull-to-Refresh: start');
    await _fetchDeltaFromServer();
    logd('Pull-to-Refresh: done');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('最新データに同期しました')),
    );
  }

  // =========================================
  // コメントをマージ（重複排除） ※既存の関数を無改変で利用
  // =========================================
  List<dynamic> _mergeComments(List<dynamic> existing, List<dynamic> newComments) {
    final commentMap = <int, dynamic>{};
    for (var comment in existing) {
      final no = comment['no'] as int?;
      if (no != null) commentMap[no] = comment;
    }
    for (var comment in newComments) {
      final no = comment['no'] as int?;
      if (no != null) commentMap[no] = comment; // 上書き
    }
    final sorted = commentMap.values.toList();
    sorted.sort((a, b) {
      final noA = (a['no'] as int?) ?? 0;
      final noB = (b['no'] as int?) ?? 0;
      return noA.compareTo(noB);
    });
    return sorted;
  }

  // =========================================
  // 初期化
  // =========================================
  Future<void> _load() async {
    await _loadScrollPosition();

    // 履歴状態とクリップ状態を取得
    final watchedIds = await getWatchedTopicIds();
    final clips = await getClippedComments();

    setState(() {
      _isWatched = watchedIds.contains(widget.topicId);
      _clippedCommentNos = clips
          .where((c) => c['topicId'] == widget.topicId)
          .map<int>((c) => c['no'] as int)
          .toSet();
    });

    // 履歴に自動追加
    if (!_isWatched) {
      await addWatchedTopicId(
        widget.topicId,
        title: widget.title,
        url: '',
        comments: widget.commentCount,
        time: '',
      );
      setState(() => _isWatched = true);
    }

    // キャッシュ読み出し
    final cacheKey     = 'comments_${widget.topicId}';
    final cachedRemote = await CacheService.load(cacheKey);

    if (cachedRemote.isNotEmpty) {
      final locals = await _loadLocalComments();
      setState(() {
        _allComments        = [...cachedRemote, ...locals];
        _displayedComments  = List.of(_allComments);
        _totalComments      = (_totalComments == 0) ? cachedRemote.length : _totalComments;
        _hasMoreComments    = cachedRemote.length < _totalComments;
        _loading            = false;
      });

      // ★ ここが重要：保存してた件数（例: 216）まで取り切ってから復元
      await _ensureSyncedToSavedAndRestore();

      // さらに新着があれば 1 回だけ同期（任意）
      if (_hasMoreComments) {
        // ignore: discarded_futures
        _fetchDeltaFromServer();
      }
    } else {
      // キャッシュ無し → 初回ページ取得後に保存値まで取り切って復元
      await _fetchFirstPage();
      await _ensureSyncedToSavedAndRestore();
    }
  }

  // 最初のページ取得（キャッシュ保存 + ローカル投稿合成 + 復元）
  Future<void> _fetchFirstPage() async {
    try {
      // ← api_service を使う
      final page = await fetchCommentsWithPagination(
        widget.topicId,
        offset: 0,
        limit: _commentsPerPage,
      );
      final newComments = (page['comments'] as List<dynamic>? ?? []);
      final total = (page['total'] as int?) ?? newComments.length;

      debugPrint('🚀 初期読み込み: ${newComments.length}/$total件');

      _allComments = newComments;
      _totalComments = total;
      _hasMoreComments = newComments.length < total;

      await CacheService.save('comments_${widget.topicId}', _allComments);

      final locals = await _loadLocalComments();
      setState(() {
        _allComments = [..._allComments, ...locals];
        _displayedComments = List.of(_allComments);
        _loading = false;
      });

      _restoreScrollAfterBuild();
    } catch (e) {
      debugPrint('API Error: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('通信にしっぱいしました')),
        );
      }
    }
  }


  // =========================================
  // クリップ / アンカー関連（データソースを _allComments に変更） // ★ 修正
  // =========================================
  Future<void> _toggleClip(Map<String, dynamic> comment) async {
    final no = comment['no'] as int;
    final isClipped = _clippedCommentNos.contains(no);

    if (isClipped) {
      await removeClippedComment(widget.topicId, no);
      _clippedCommentNos.remove(no);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('クリップを解除しました')));
    } else {
      await addClippedComment(
        topicId: widget.topicId,
        topicTitle: widget.title,
        commentNo: no,
        commentBody: comment['body'] ?? '',
        time: comment['time'] ?? '',
        plus: comment['plus'] ?? 0,
        minus: comment['minus'] ?? 0,
      );
      _clippedCommentNos.add(no);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('クリップに保存しました')));
    }
    setState(() {});
  }

  dynamic _getCommentByNo(int no) {
    try {
      return _allComments.firstWhere((c) => c['no'] == no); // ★ 修正
    } catch (e) {
      return {};
    }
  }

  void _jumpToComment(int no) {
    debugPrint('🔗 アンカークリック: No.$no');
    final index = _allComments.indexWhere((c) => c['no'] == no); // ★ 修正
    debugPrint('📍 コメント インデックス: $index / 総数: ${_allComments.length}');
    if (index != -1) {
      final estimatedOffset = index * 120.0;
      debugPrint('📐 スクロール目標: $estimatedOffset');
      _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).catchError((_) {
        _scrollController.jumpTo(estimatedOffset);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No.$no へ移動しました')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントが見つかりません')),
      );
    }
  }

  // ===== アンカープレビュー =====
  void _showAnchorPreview(int no) {
    debugPrint('👀 アンカープレビュー: No.$no');
    final comment = _getCommentByNo(no);
    
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントが見つかりません')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          color: Colors.white,
          child: Column(
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'No.${comment['no']}  ${comment['time'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
              ),
              // コメント内容
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // アンカー表示
                        if ((comment['anchors'] as List?)?.isNotEmpty ?? false)
                          _buildAnchorText(List<int>.from(comment['anchors'] ?? [])),
                        if ((comment['reverse_anchors'] as List?)?.isNotEmpty ?? false)
                          _buildReverseAnchorText(List<int>.from(comment['reverse_anchors'] ?? [])),
                        // コメント本文
                        Text(
                          comment['body'] ?? '',
                          style: const TextStyle(fontSize: 15),
                        ),
                        // 画像
                        if (comment['image_url'] != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Image.network(
                                    comment['image_url'],
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.error),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                comment['image_url'],
                                height: 200,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        // プラス/マイナス/クリップ
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '＋${comment['plus'] ?? 0}',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '−${comment['minus'] ?? 0}',
                                  style: const TextStyle(color: Colors.blueGrey),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _clippedCommentNos.contains(comment['no'])
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _clippedCommentNos.contains(comment['no'])
                                    ? Colors.pinkAccent
                                    : null,
                                size: 22,
                              ),
                              onPressed: () async {
                                await _toggleClip(comment);
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnchorText(List<int> anchors) {
    if (anchors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Wrap(
        spacing: 4,
        children: anchors.map((no) {
          final referencedComment = _getCommentByNo(no);
          final isAvailable = referencedComment.isNotEmpty;

          return GestureDetector(
            onTap: () => _showAnchorPreview(no),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.blue.shade100 : Colors.grey.shade200,
                border: Border.all(
                  color: isAvailable ? Colors.blue.shade300 : Colors.grey.shade300,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '>>$no',
                style: TextStyle(
                  fontSize: 12,
                  color: isAvailable ? Colors.blue.shade700 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReverseAnchorText(List<int> reverseAnchors) {
    if (reverseAnchors.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          const Text(
            '参照されている: ',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              children: reverseAnchors.take(5).map((no) {
                return GestureDetector(
                  onTap: () => _showAnchorPreview(no),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '<<$no',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (reverseAnchors.length > 5)
            Text(
              ' +${reverseAnchors.length - 5}件',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // =========================================
  // UI
  // =========================================
  @override
  Widget build(BuildContext context) {
    final remoteCount = _serverSyncedCount();                         // ★ 修正
    final localCount = _allComments.length - remoteCount;             // ★ 修正

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              // 例: 「表示: 123(リモート)/403 +2(ローカル)」
              '表示: $remoteCount/$_totalComments'
              '${localCount > 0 ? '  +$localCount(ローカル)' : ''}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPostDialog,
        child: const Icon(Icons.add_comment),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _saveScrollPosition();
                // 最後のコメント到達後の下スワイプ検知
                _onOverscrollBottom();
                return false;
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // オーバースクロール（過度なスクロール）検知
                  if (notification is OverscrollNotification) {
                    // 下方向へのオーバースクロール（direction > 0）
                    if (notification.overscroll > 0) {
                      _onOverscrollBottom();
                    }
                  }
                  return false;
                },
                child: RefreshIndicator(
                  onRefresh: fetchComments,
                  child: Scrollbar(
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      key: PageStorageKey('topic_${widget.topicId}'),
                      controller: _scrollController,
                      itemCount: _allComments.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _allComments.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Column(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 8),
                                Text(
                                  '読み込み中... ($remoteCount/$_totalComments)',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final c = _allComments[i];
                      final no = c['no'] ?? '-';
                      final time = c['time'] ?? '';
                      final body = c['body'] ?? '';
                      final plus = c['plus'] ?? 0;
                      final minus = c['minus'] ?? 0;
                      final anchors = List<int>.from(c['anchors'] ?? []);
                      final reverseAnchors = List<int>.from(c['reverse_anchors'] ?? []);

                      return ListTile(
                        title: Text(
                          'No.$no  $time${c['isLocal'] == true ? '（ローカル）' : ''}', // ★ 修正: ローカル表示
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (anchors.isNotEmpty) _buildAnchorText(anchors),
                            if (reverseAnchors.isNotEmpty) _buildReverseAnchorText(reverseAnchors),
                            Text(body, style: const TextStyle(fontSize: 15)),
                            if (c['image_url'] != null) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: Image.network(
                                        c['image_url'],
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(Icons.error),
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    c['image_url'],
                                    height: 200,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const SizedBox(
                                        height: 200,
                                        child: Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () async {
                                        if (c['isLocal'] == true) return; // ★ 修正: ローカルは評価しない
                                        final commentId = 'vbox$no';
                                        final success = await rateComment(widget.topicId, commentId, 1);
                                        if (success && mounted) {
                                          setState(() => c['plus'] = (c['plus'] ?? 0) + 1);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('プラスを送信しました')),
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text('＋$plus',
                                            style: const TextStyle(color: Colors.redAccent)),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        if (c['isLocal'] == true) return; // ★ 修正
                                        final commentId = 'vbox$no';
                                        final success = await rateComment(widget.topicId, commentId, -1);
                                        if (success && mounted) {
                                          setState(() => c['minus'] = (c['minus'] ?? 0) + 1);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('マイナスを送信しました')),
                                          );
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text('−$minus',
                                            style: const TextStyle(color: Colors.blueGrey)),
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(
                                    _clippedCommentNos.contains(no)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _clippedCommentNos.contains(no)
                                        ? Colors.pinkAccent
                                        : null,
                                    size: 22,
                                  ),
                                  onPressed: () => _toggleClip(c),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }  // 既存の _openPostDialog, _removeFromWatch などはそのまま使えます
  Future<void> _openPostDialog() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('コメント入力'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'コメントを入力してください',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('確認')),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('投稿を確認'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('戻る')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('投稿')),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommentPostWebView(topicId: widget.topicId, text: text),
        ),
      );

      if (success == true) {
        await _saveLocalComment(text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿を送信しました')),
        );
      }
    }
  }

  Future<void> _removeFromWatch() async {
    await removeWatchedTopicId(widget.topicId);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('履歴から削除しました')));
    setState(() => _isWatched = false);
  }
}
