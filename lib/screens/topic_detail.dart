import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../utils/platform_helper.dart';
import 'comment_post_webview.dart';
import 'image_viewer_page.dart';

class TopicDetailScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String posted_at; // ★ 追加

  // ★ 追加: テスト用バイパス
  final bool enableRefresh;
  final bool testingBypassInit;
  final List<Map<String, dynamic>>? testingInitialComments;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.posted_at, // ★ 追加
    this.enableRefresh = true,
    this.testingBypassInit = false,
    this.testingInitialComments,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  List<dynamic> _allComments = [];            // サーバ同期済み + ローカル投稿を含む最新の「表示用」ソース
  bool _loading = true;
  bool _loadingMore = false;
  bool _isWatched = false;
  int _totalComments = 0;

  static const int _commentsPerPage = 500;
  static const double _kItemExtent = 150.0; // 推定アイテム高さを統一
  final ScrollController _scrollController = ScrollController();
  int _savedCommentNo = 0;        // ★ 修正: ピクセル位置→コメントNo
  Set<int> _clippedCommentNos = {};
  // ★ 追加: 復元のための保存値
  int _savedSyncedCount = 0;      // 保存しておいた「サーバ同期済み件数」
  bool _needsDeferredRestore = false; // 差分取得後に再ジャンプが必要か
  bool _isRestoringScroll = false; // スクロール復現中フラグ

  // ★ 追加: 最下部到達時の自動差分取得用
  Timer? _autoThrottle;
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();

    // ★ 追加: テストバイパス
    if (widget.testingBypassInit) {
      _allComments = (widget.testingInitialComments ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _totalComments = _allComments.length;
      _loading = false;
      // 復元や差分同期など一切走らせない
      return;
    }

    // logd('initState: topicId=${widget.topicId}, title=${widget.title}');
    _load();

    // ★ 追加: 最下部到達時の自動差分取得リスナー
    _scrollController.addListener(() {
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 80) {
        // スロットル: 1秒以内に複数回呼ばれないようにする
        if (_autoThrottle?.isActive ?? false) return;
        _autoThrottle = Timer(const Duration(seconds: 1), () {});
        _fetchDeltaFromServer(); // 差分API呼び出し
      }
    });
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _autoThrottle?.cancel(); // ★ 追加: Timer をキャンセル
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================
  // ユーティリティ
  // =========================================

  // 「サーバ同期済み」件数（ローカル投稿は除外） // ★ 修正
  int _serverSyncedCount() => _allComments.where((c) => c['isLocal'] != true).length;

  // ★ 追加: 最終同期時刻の表示用文字列
  String get _lastSyncDisplay {
    final d = _lastSync;
    if (d == null) return '—';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // スクロール復現 // ★ 修正: ピクセル位置→コメントNo
  void _restoreScrollAfterBuild() {
    if (_savedCommentNo <= 0) {
      logd('📍 スクロール復現: 保存位置なし');
      _isRestoringScroll = false;
      return;
    }
    
    _isRestoringScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 保存されたNoのコメントがリスト内のどのインデックスか探す
      int targetIndex = -1;
      for (int i = 0; i < _allComments.length; i++) {
        if ((_allComments[i]['no'] as int?) == _savedCommentNo) {
          targetIndex = i;
          break;
        }
      }
      
      if (targetIndex < 0) {
        logd('📍 スクロール復現: コメントNo($_savedCommentNo)が見つかりません');
        _isRestoringScroll = false;
        return;
      }
      
      // ListView.builder内でのコメント位置を計算
      // アイテム高さを _kItemExtent と仮定（ヘッダー等込み）
      final estimatedOffset = targetIndex * _kItemExtent;
      
      if (!_scrollController.hasClients) {
        _isRestoringScroll = false;
        return;
      }
      
      // さらに1フレーム待ってから復元（ビルド完全終了まで待つ）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final max2 = _scrollController.position.maxScrollExtent;
          final jump2 = estimatedOffset.clamp(0.0, max2);
          _scrollController.jumpTo(jump2);
          logd('📍 スクロール復現完了: commentNo=$_savedCommentNo index=$targetIndex offset=$jump2 max=$max2');
          _isRestoringScroll = false;
        }
      });
    });
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

    var newComments = (page['comments'] as List<dynamic>? ?? []);
    
    final total = (page['total'] as int?) ?? _totalComments;

    final existingRemote = _allComments.where((c) => c['isLocal'] != true).toList();
    final mergedRemote  = _mergeComments(existingRemote, newComments);
    final locals        = _allComments.where((c) => c['isLocal'] == true).toList();

    setState(() {
      _totalComments  = total;
      _allComments    = [...mergedRemote, ...locals];
      _lastSync = DateTime.now(); // ★ 追加: 最終同期時刻を更新
    });

    await CacheService.saveList('comments_${widget.topicId}', mergedRemote);

    // 復元待ち && 目標件数に到達したらもう一度 jump
    if (_needsDeferredRestore && _serverSyncedCount() >= _savedSyncedCount) {
      _needsDeferredRestore = false;
      logd('📍 差分取得後のスクロール復現: ${_serverSyncedCount()}/${_savedSyncedCount}件');
      _restoreScrollAfterBuild();
    }
  } catch (e) {
    debugPrint('❌ 差分取得エラー: $e');
  } finally {
    if (mounted) setState(() => _loadingMore = false);
  }
}



  // =========================================
  // スクロール位置保存
  // =========================================
  Future<void> _saveScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (_scrollController.hasClients) {
      // 現在のスクロール位置に最も近いコメントのNoを取得
      int commentNo = 0;
      final current = _scrollController.offset;
      
      // シンプルな推定: (offset / 平均アイテム高さ) でアイテムインデックスを推定
      // ただしここでは、_allComments内のコメントのNoを保存する
      if (_allComments.isNotEmpty && current > 0) {
        // 表示中のコメント一覧から、現在位置に近いNoを推定
        final estimatedIndex = (current / _kItemExtent).floor().clamp(0, _allComments.length - 1);
        if (estimatedIndex < _allComments.length) {
          commentNo = _allComments[estimatedIndex]['no'] as int? ?? 0;
        }
      }
      
      await prefs.setInt('scroll_${widget.topicId}', commentNo);
      await prefs.setInt('synced_${widget.topicId}', _serverSyncedCount());
      // logd('💾 スクロール位置保存: commentNo=$commentNo synced=${_serverSyncedCount()}');
    }
  }

  Future<void> _loadScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    _savedCommentNo = prefs.getInt('scroll_${widget.topicId}') ?? 0;
    _savedSyncedCount = prefs.getInt('synced_${widget.topicId}') ?? 0;
    logd('📖 スクロール位置読み込み: commentNo=$_savedCommentNo synced=$_savedSyncedCount');
  }


  // =========================================
  // ローカル投稿
  // =========================================

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
    // PlatformHelper.showSnackBar(context, '最新データに同期しました');
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
        comments: widget.commentCount,
        posted_at: widget.posted_at,
      );
      setState(() => _isWatched = true);
    }

    // キャッシュ読み出し
    final cacheKey     = 'comments_${widget.topicId}';
    final cachedRemote = await CacheService.loadList(cacheKey);

    if (cachedRemote.isNotEmpty) {
      final locals = await _loadLocalComments();
      setState(() {
        _allComments        = [...cachedRemote, ...locals];
        // ★ 修正: キャッシュの件数を一時的に表示する（あとで API 呼び出しで上書き）
        _totalComments      = cachedRemote.length;
        _loading            = false;
      });

      _restoreScrollAfterBuild();
      return;
    } else {
      // キャッシュ無し → 初回ページ取得後に保存値まで取り切って復元
      await _fetchFirstPage();
      _restoreScrollAfterBuild();
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
      final newComments = (page['comments'] as List<dynamic>? ?? []).toList();
      final total = (page['total'] as int?) ?? newComments.length;

      debugPrint('🚀 初期読み込み: ${newComments.length}/$total件');

      _allComments = newComments;
      _totalComments = total;

      await CacheService.saveList('comments_${widget.topicId}', _allComments);

      final locals = await _loadLocalComments();
      setState(() {
        _allComments = [..._allComments, ...locals];
        _loading = false;
      });

      _restoreScrollAfterBuild();
    } catch (e) {
      debugPrint('API Error: $e');
      setState(() => _loading = false);
      if (mounted) {
        PlatformHelper.showSnackBar(context, '通信に失敗しました');
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
      // PlatformHelper.showSnackBar(context, 'クリップを解除しました');
    } else {
      await addClippedComment(
        topicId: widget.topicId,
        topicTitle: widget.title,
        commentNo: no,
        commentBody: comment['body'] ?? '',
        posted_at: comment['posted_at'] ?? '',
        plus: comment['plus'] ?? 0,
        minus: comment['minus'] ?? 0,
      );
      _clippedCommentNos.add(no);
      // PlatformHelper.showSnackBar(context, 'クリップに保存しました');
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

  // ignore: unused_element
  void _jumpToComment(int no) {
    debugPrint('🔗 アンカークリック: No.$no');
    final index = _allComments.indexWhere((c) => c['no'] == no); // ★ 修正
    debugPrint('📍 コメント インデックス: $index / 総数: ${_allComments.length}');
    if (index != -1) {
      final estimatedOffset = index * _kItemExtent;
      debugPrint('📐 スクロール目標: $estimatedOffset');
      _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).catchError((_) {
        _scrollController.jumpTo(estimatedOffset);
      });
      // PlatformHelper.showSnackBar(context, 'No.$no へ移動しました');
    } else {
      PlatformHelper.showSnackBar(context, 'コメントが見つかりません');
    }
  }

  // ===== アンカープレビュー =====
  void _showAnchorPreview(int no) {
    debugPrint('👀 アンカープレビュー: No.$no');
    final comment = _getCommentByNo(no);
    
    if (comment.isEmpty) {
      PlatformHelper.showSnackBar(context, 'コメントが見つかりません');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: CupertinoColors.separator),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'No.${comment['no']}  ${comment['posted_at'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(4),
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(CupertinoIcons.xmark, size: 20),
                  ),
                ],
              ),
            ),
            // コメント内容
            Expanded(
              child: SingleChildScrollView(
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
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => ImageViewerPage(url: comment['image_url']),
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
                                return SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: PlatformHelper.buildLoadingIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Icon(CupertinoIcons.photo, size: 40, color: CupertinoColors.systemGrey),
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
                                style: const TextStyle(color: Color(0xFFED6D74)),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '−${comment['minus'] ?? 0}',
                                style: const TextStyle(color: CupertinoColors.secondaryLabel),
                              ),
                            ],
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(4),
                            onPressed: () async {
                              await _toggleClip(comment);
                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                            child: Icon(
                              _clippedCommentNos.contains(comment['no'])
                                  ? CupertinoIcons.heart_fill
                                  : CupertinoIcons.heart,
                              color: _clippedCommentNos.contains(comment['no'])
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.secondaryLabel,
                              size: 22,
                            ),
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
                color: isAvailable ? CupertinoColors.systemBlue.withOpacity(0.1) : CupertinoColors.systemGrey.withOpacity(0.1),
                border: Border.all(
                  color: isAvailable ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '>>$no',
                style: TextStyle(
                  fontSize: 12,
                  color: isAvailable ? CupertinoColors.systemBlue : CupertinoColors.secondaryLabel,
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
          Expanded(
            child: Wrap(
              spacing: 4,
              children: reverseAnchors.take(5).map((no) {
                return GestureDetector(
                  onTap: () => _showAnchorPreview(no),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withOpacity(0.1),
                      border: Border.all(
                        color: CupertinoColors.systemOrange,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '<<$no',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemOrange,
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
              style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
            ),
        ],
      ),
    );
  }

  // URL表示ウィジェット
  // ignore: unused_element
  Widget _buildUrlsWidget(List<dynamic> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: urls.map((urlData) {
          String url = '';
          String title = '';
          String? description;
          String? thumbnail;

          // Map型とCommentUrl型の両方に対応
          if (urlData is Map<String, dynamic>) {
            url = urlData['url'] ?? '';
            title = urlData['title'] ?? '';
            description = urlData['description'];
            thumbnail = urlData['thumbnail'];
          } else if (urlData is CommentUrl) {
            url = urlData.url;
            title = urlData.title;
            description = urlData.description;
            thumbnail = urlData.thumbnail;
          }

          if (url.isEmpty) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () async {
              final Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                border: Border.all(color: CupertinoColors.separator),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // サムネイル
                  if (thumbnail != null && thumbnail.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                      child: Image.network(
                        thumbnail,
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 100,
                            height: 80,
                            color: CupertinoColors.systemGrey6,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CupertinoActivityIndicator(),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 80,
                          color: CupertinoColors.systemGrey6,
                          child: const Center(
                            child: Icon(CupertinoIcons.photo, size: 24, color: CupertinoColors.systemGrey),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 100,
                      height: 80,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.link, size: 24, color: CupertinoColors.systemGrey),
                      ),
                    ),
                  // タイトルと説明
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (description != null && description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // =========================================
  // UI
  // =========================================
  @override
  Widget build(BuildContext context) {
    final remoteCount = _serverSyncedCount();
    final localCount = _allComments.length - remoteCount;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'コメント: ${widget.commentCount}',
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _openPostDialog,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _buildCommentsList(context),
      ),
    );
  }

  Widget _buildCommentsList(BuildContext context) {
    return _loading
        ? Center(child: PlatformHelper.buildLoadingIndicator())
        : NotificationListener<ScrollEndNotification>(
            onNotification: (_) {
              _saveScrollPosition();
              return false;
            },
            child: _buildRefreshableList(context),
          );
  }

  Widget _buildRefreshableList(BuildContext context) {
    return CupertinoScrollbar(
      controller: _scrollController,
      child: CustomScrollView(
        controller: _scrollController,
        primary: false,
        slivers: [
          // ★ 変更: テスト時はRefreshControlを無効化できるように
          if (widget.enableRefresh)
            CupertinoSliverRefreshControl(
              onRefresh: fetchComments,
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i == _allComments.length) {
                  if (_loadingMore) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CupertinoActivityIndicator(),
                    );
                  }
                  return const SizedBox.shrink();
                }
                return _buildCommentItem(context, _allComments[i], i);
              },
              childCount: _allComments.length + (_loadingMore ? 1 : 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(BuildContext context, dynamic c, int i) {
    final no = c['no'] ?? '-';
    final posted_at = c['posted_at'] ?? '';
    final body = c['body'] ?? '';
    final plus = c['plus'] ?? 0;
    final minus = c['minus'] ?? 0;
    final anchors = List<int>.from(c['anchors'] ?? []);
    final reverseAnchors = List<int>.from(c['reverse_anchors'] ?? []);
    final urls = (c['urls'] as List?) ?? [];

    // ★ デバッグ: posted_at が空でないか確認
    if (i < 3) {
      debugPrint('🔍 Comment[$i]: no=$no, posted_at="$posted_at", has_posted_at=${posted_at.isNotEmpty}');
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No.$no  $posted_at${c['isLocal'] == true ? ' （ローカル）' : ''}',
            style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 8),
          if (anchors.isNotEmpty) _buildAnchorText(anchors),
          if (reverseAnchors.isNotEmpty) _buildReverseAnchorText(reverseAnchors),
          Text(body, style: const TextStyle(fontSize: 15)),
          if (urls.isNotEmpty) _buildUrlsWidget(urls),
          if (c['image_url'] != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ImageViewerPage(url: c['image_url']),
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
                        child: CupertinoActivityIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(
                        CupertinoIcons.photo,
                        size: 40,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          _buildPlusMinusGraph(plus, minus),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  if (c['isLocal'] == true) return;
                  final commentId = 'vbox$no';
                  final success = await rateComment(widget.topicId, commentId, 1);
                  if (success && mounted) {
                    setState(() => c['plus'] = (c['plus'] ?? 0) + 1);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('＋$plus',
                      style: const TextStyle(color: CupertinoColors.systemRed)),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  if (c['isLocal'] == true) return;
                  final commentId = 'vbox$no';
                  final success = await rateComment(widget.topicId, commentId, -1);
                  if (success && mounted) {
                    setState(() => c['minus'] = (c['minus'] ?? 0) + 1);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('−$minus',
                      style: const TextStyle(color: CupertinoColors.secondaryLabel)),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await _toggleClip(c);
                },
                child: Icon(
                  _clippedCommentNos.contains(no)
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
                  color: _clippedCommentNos.contains(no)
                      ? CupertinoColors.systemRed
                      : CupertinoColors.secondaryLabel,
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPostDialog() async {
    if (!mounted) return;
    
    // 直接本家に遷移（ダイアログなし）
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => CommentPostWebView(
          topicId: widget.topicId,
          title: widget.title,
          postPageUrl: Uri.parse('https://girlschannel.net/topics/${widget.topicId}'),
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _removeFromWatch() async {
    await removeWatchedTopicId(widget.topicId);
    PlatformHelper.showSnackBar(context, '履歴から削除しました');
    setState(() => _isWatched = false);
  }

  /// プラス・マイナスを表示する横長の棒グラフを作成
  Widget _buildPlusMinusGraph(int plus, int minus) {
    final total = plus + minus;

    // 合計が0の場合は表示しない
    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        // プラスの棒（ピンク）
        Expanded(
          flex: plus,
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFED6D74),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(plus > 0 ? 4 : 0),
                bottomLeft: Radius.circular(plus > 0 ? 4 : 0),
              ),
            ),
            alignment: Alignment.center,
            child: plus > 0
                ? Text(
                    plus.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  )
                : null,
          ),
        ),
        // マイナスの棒（灰色）
        Expanded(
          flex: minus,
          child: Container(
            height: 20,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(minus > 0 ? 4 : 0),
                bottomRight: Radius.circular(minus > 0 ? 4 : 0),
              ),
            ),
            alignment: Alignment.center,
            child: minus > 0
                ? Text(
                    minus.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
