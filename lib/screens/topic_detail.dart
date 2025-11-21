// --- UI専用: TopicDetailScreen ---
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/log.dart';

import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import '../controllers/topic_detail_controller.dart';
import '../widgets/measure_size.dart';
import '../utils/variable_list_measurer.dart';
import 'comment_compose_page.dart';
import 'comment_post_webview.dart';
import 'image_viewer_page.dart';
import '../widgets/comment_tile.dart';
import '../widgets/anchor_preview_sheet.dart';
import '../widgets/topic_menu_sheet.dart';

class TopicDetailScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String posted_at;
  final int? initialJumpTo;
  final bool enableRefresh;
  final bool saveReadPosition; // ★ 追加

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.posted_at,
    this.initialJumpTo,
    this.enableRefresh = true,
    this.saveReadPosition = true, // ★ デフォルトは true
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  // ========== フィールド群 ==========
  late final TopicDetailController _vm;
  static const int _pageSize = 100;
  final PageController _pc = PageController();
  final Map<int, ScrollController> _pageScroll = {};             // page -> ScrollController
  final Map<int, VariableListMeasurer> _pageMeas = {};           // page -> measurer
  int _currentPage = 0;

  bool _restoring = false;          // 復元中は保存/ロードを止める
  bool _restoredOnce = false;       // 一度でも復元が成功したか
  bool _loadingMore = false;        // 末尾ページの追加ロード中
  int? _restoreTargetPageNo;        // 復元ターゲットのページ番号
  bool _boostCacheDuringRestore = false; // 復元中は cacheExtent を爆上げ
  static const double _loadMoreThreshold = 300; // 末尾付近の閾値

  @override
  void initState() {
    super.initState();
    _vm = TopicDetailController(
      topicId: widget.topicId,
      title: widget.title,
      commentCount: widget.commentCount,
      postedAt: widget.posted_at,
      enableRefresh: widget.enableRefresh,
      saveReadPosition: widget.saveReadPosition, // ★ 追加
    )..addListener(_onVmChanged);

    // 初期化処理
    _vm.init().then((_) {
      if (!mounted) return;
      if (widget.initialJumpTo != null && widget.initialJumpTo! > 0) {
_vm.clearScrollFractionOnly();
        _tryRestoreIfNeeded(targetNo: widget.initialJumpTo);
      } else {
        _tryRestoreIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    // 現在ページの位置を保存
    _saveFromPage(_currentPage);

    // ページ用 ScrollController を全部 dispose
    for (final sc in _pageScroll.values) {
      sc.dispose();
    }
    _pc.dispose();

    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  // ==== VM更新 ====
  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});

    // ★ initialJumpTo がある場合は、initState 側の明示的な呼び出しに任せるのでここでは何もしない
    if (widget.initialJumpTo != null && widget.initialJumpTo! > 0) {
      return;
    }

    // 初回データ到着後は復元を試みる
    if (!_restoredOnce && !_vm.loading) {
      _scheduleTryRestore();
    }
  }

  // ========== 2) 追加: ページングのヘルパー ==========
  int _pageCountFor(int total) => (total + _pageSize - 1) ~/ _pageSize;

  int get _pageCountLive => _pageCountFor(_vm.comments.length);
  bool get _hasPrev => _currentPage > 0;
  bool get _hasNext => _currentPage < _pageCountLive - 1;

  void _goToPage(int p) {
    final tgt = p.clamp(0, _pageCountLive > 0 ? _pageCountLive - 1 : 0);
    if (_pc.hasClients) {
      _saveFromPage(_currentPage); // 切り替え前に位置を保存
      _pc.animateToPage(
        tgt,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  void _goNextPage() => _hasNext ? _goToPage(_currentPage + 1) : null;
  void _goPrevPage() => _hasPrev ? _goToPage(_currentPage - 1) : null;

  List<Comment> _itemsOfPage(int page, List<Comment> all) {
    final start = page * _pageSize;
    final end = (start + _pageSize > all.length) ? all.length : (start + _pageSize);
    if (start >= all.length || start >= end) return <Comment>[];
    return all.sublist(start, end);
  }

  ScrollController _scForPage(int page) {
    return _pageScroll.putIfAbsent(page, () {
      final sc = ScrollController();
      sc.addListener(() => _onPageScroll(page));
      return sc;
    });
  }

  VariableListMeasurer _measForPage(int page) {
    return _pageMeas.putIfAbsent(page, () => VariableListMeasurer());
  }

  // ========== 3) 追加: 末尾ページの自動ロード & 保存 ==========
  void _onPageScroll(int page) {
    if (_restoring) return;
    final sc = _scForPage(page);
    if (!sc.hasClients) return;

    // 末尾ページなら差分読み込み
    final lastPage = _pageCountFor(_vm.comments.length) - 1;
    if (page == lastPage && !_loadingMore) {
      if (sc.position.extentAfter <= _loadMoreThreshold) {
        _fetchMoreDelta();
      }
    }
  }

  Future<void> _fetchMoreDelta() async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      final added = await _vm.fetchDelta();
      if (!mounted) return;
      if (added > 0) setState(() {}); // ページ数/末尾更新
    } finally {
      _loadingMore = false;
    }
  }

  // 現在ページから保存（indexInPage + fraction -> globalIndexへ変換）
  void _saveFromPage(int page) {
    if (_restoring) return;

    final sc = _scForPage(page);
    if (!sc.hasClients) return;

    final all = _vm.comments;
    if (all.isEmpty) return;

    final pageItems = _itemsOfPage(page, all);
    final meas = _measForPage(page);
    meas.ensureCapacity(pageItems.length);

    final off = sc.offset;
    final idxInPage = meas.offsetToIndex(off, pageItems.length);
    final rowTop = meas.indexToOffset(idxInPage);
    final h = meas.getItemHeight(idxInPage) ?? meas.fallbackHeight;
    final frac = (h <= 0) ? 0.0 : ((off - rowTop) / h).clamp(0.0, 1.0);

    final globalIndex = page * _pageSize + idxInPage;
    _vm.saveScrollByIndexAndFraction(globalIndex.toInt(), frac);
  }

  // ========== 4) 追加: 復元（savedCommentNo をページにマップ） ==========
  void _scheduleTryRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreIfNeeded();
    });
  }

  /// ScrollController のアタッチを待つ
  Future<void> _waitForAttach(ScrollController sc) async {
    for (int i = 0; i < 30; i++) {
      if (sc.hasClients &&
          sc.position.hasPixels &&
          sc.position.hasViewportDimension) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  /// PageController のアタッチを待つ
  Future<void> _waitForPageController() async {
    for (int i = 0; i < 30; i++) {
      if (_pc.hasClients && _pc.position.hasPixels) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _tryRestoreIfNeeded({int? targetNo}) async {
    // 1. 実行可能かチェックし、復元モードを開始
    final target = _startRestoreProcess(targetNo);
    if (target == null) return;

    try {
      // 2. 必要なデータ（コメント）がメモリにあるか確認・取得
      final hasData = await _ensureDataAvailable(target);
      if (!hasData) return; // データがなければ諦める（またはリトライ予約）

      // 3. ターゲットのページ番号を特定
      final pageIndex = _vm.indexByNo[target]! ~/ _pageSize; // nullチェックはensureDataで保証済とする

      // 4. そのページへ横移動 (PageView)
      await _jumpToTargetPage(pageIndex);

      // 5. ページ内で該当コメントまで縦スクロール (ScrollController)
      //    ※ここは複雑なので専用メソッドに任せる
      final success = await _seekAndScrollToComment(pageIndex, target);

      if (!success) {
        // 失敗したらリトライをスケジュール
        _scheduleTryRestore();
      }
    } finally {
      // 6. 終了処理（フラグ解除など）
      _finishRestoreProcess(targetNo: target);
    }
  }

  // 復元を開始できるか判定し、フラグを立てる
  int? _startRestoreProcess(int? targetNo) {
    // 再入防止
    if (_restoredOnce && targetNo == null) return null;
    if (_vm.loading || _restoring) return null;

    final savedNo = targetNo ?? _vm.savedCommentNo;
    if (savedNo <= 0) {
      _restoredOnce = true;
      return null;
    }

    _restoring = true;
    return savedNo;
  }

  // 終了処理
  void _finishRestoreProcess({int? targetNo}) {
    _restoring = false;
    _boostCacheDuringRestore = false;
    _restoreTargetPageNo = null;

    if (mounted) setState(() {}); // CacheExtentなどを元に戻す

    // Enable measurement for the current page after restore
    _measForPage(_currentPage).needsUpdate = true;

    // 今回のターゲットへの復元が終わったら完了フラグを立てる
    if (targetNo == null || targetNo == _vm.savedCommentNo) {
      // 成功/失敗に関わらず「一度試した」とする場合
      // (成功時のみtrueにするなら _seekAndScrollToComment の戻り値を見る)
    }
  }

  Future<bool> _ensureDataAvailable(int targetNo) async {
    await _vm.ensureContainsNo(targetNo);
    if (!mounted) return false;
    
    // データロード後もインデックスが見つからなければ失敗
    if (!_vm.indexByNo.containsKey(targetNo)) {
      _scheduleTryRestore(); // 再ロードが必要かもしれないのでスケジュール
      return false;
    }
    return true;
  }

  Future<void> _jumpToTargetPage(int pageIndex) async {
    _restoreTargetPageNo = pageIndex;
    _boostCacheDuringRestore = true;
    if (mounted) setState(() {});

    await _waitForPageController();
    
    if (_pc.hasClients && _pc.page?.round() != pageIndex) {
      _pc.jumpToPage(pageIndex);
    }
    
    // スクロールコントローラーがアタッチされるのを待つ
    await _waitForAttach(_scForPage(pageIndex));
    // レイアウト安定待ち
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<bool> _seekAndScrollToComment(int pageIndex, int targetNo) async {
    final sc = _scForPage(pageIndex);
    final meas = _measForPage(pageIndex);
    
    // 1. まず概算位置へジャンプ（画面外だと描画されないため）
    _performApproximateJump(pageIndex, targetNo, sc, meas);

    // 2. 実測ベースの厳密な位置合わせ（最大60フレーム試行）
    for (int attempt = 0; attempt < 60; attempt++) {
      if (!mounted) return false;

      // UI要素（RenderObject）が見つかるかトライ
      final found = await _tryAlignVisible(targetNo, pageIndex);
      if (found) {
        // 成功したら現在位置を保存して終了
        _saveFromPage(pageIndex);
        _restoredOnce = true;
        return true; 
      }
      
      // 見つからない場合、概算位置を微調整して次フレームへ
      _adjustApproximatePosition(pageIndex, targetNo, sc, meas);
      await Future.delayed(const Duration(milliseconds: 16));
    }


    return false; // タイムアウト
  }

  // 概算ジャンプ処理
  void _performApproximateJump(int page, int targetNo, ScrollController sc, VariableListMeasurer meas) {
    final all = _vm.comments;
    final pageItems = _itemsOfPage(page, all);
    final roughIndex = pageItems.indexWhere((item) => item.id == targetNo);

    if (roughIndex >= 0) {
      meas.markRestoreTargetIndex(roughIndex); // 追従モードON
      if (sc.hasClients) {
        try {
          final guess = meas.indexToOffset(roughIndex);
          sc.jumpTo(guess);
        } catch (_) {}
      }
    }
  }

  // 厳密な位置合わせ（Contextが見つかればスクロールしてtrueを返す）
  Future<bool> _tryAlignVisible(int targetNo, int pageIndex) async {
    final key = _vm.keyForCommentNo(targetNo);
    final ctx = key.currentContext;

    if (ctx == null) return false;

    // コンテキストが見つかった＝描画された
    // 1. 行頭を合わせる
    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: Duration.zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );

    // 2. 途中まで読んでいた場合の微調整（Fraction）
    final box = ctx.findRenderObject() as RenderBox?;
    final h = box?.size.height ?? 0.0;
    final frac = _vm.savedLocalFraction.clamp(0.0, 0.9999);

    if (h > 0 && frac > 0) {
      final sc = _scForPage(pageIndex);
      if (sc.hasClients) {
        final offset = (sc.offset + h * frac).clamp(0.0, sc.position.maxScrollExtent);
        sc.jumpTo(offset);
      }
    }

    // 後始末
    _vm.clearScrollFractionOnly();
    _measForPage(pageIndex).markRestoreTargetIndex(null); // 追従OFF
    return true;
  }

  // 見つからなかった場合の微調整（コンテキストが無いときに呼ばれる）
  void _adjustApproximatePosition(int page, int targetNo, ScrollController sc, VariableListMeasurer meas) {
     // 実装は概算ジャンプと同じロジックで「最新の計測データ」を使って再ジャンプするだけ
     // ここでは _performApproximateJump を呼ぶだけでも良いが、
     // インデックス検索コストを避けるなら index を引数に回す工夫も可
     _performApproximateJump(page, targetNo, sc, meas);
  }


  // ==== UI ====
  bool _allowPop = false;

  @override
  Widget build(BuildContext context) {
    final items = _vm.comments;
    final pageCount = _pageCountFor(items.length);

    final pageView = PageView.builder(
      controller: _pc,
      onPageChanged: (p) {
        _saveFromPage(_currentPage);      // 追加：切り替え前のページ位置を保存
        setState(() => _currentPage = p);
      },
      itemCount: pageCount > 0 ? pageCount : 1, // 0件でも空ページ1つは描画
      itemBuilder: (ctx, page) {
        final pageItems = _itemsOfPage(page, items);
        final meas = _measForPage(page);
        meas.ensureCapacity(pageItems.length);

        final sc = _scForPage(page);

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification) {
              _saveFromPage(page);
            }
            return false;
          },
          child: CupertinoScrollbar(
            controller: sc,
            child: CustomScrollView(
              controller: sc,
              cacheExtent: (_boostCacheDuringRestore && _restoreTargetPageNo == page)
                  ? 50000.0
                  : 1200.0,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx2, i) {
                      final Comment c = pageItems.isNotEmpty ? pageItems[i] : Comment(id: 0, time: '', text: '', plus: 0, minus: 0);


                      final bool shouldMeasure = _restoring || meas.needsUpdate;
                      Widget content = Container(
                        key: c.id > 0 ? _vm.keyForCommentNo(c.id) : null,
                        child: CommentTile(
                          comment: c,
                          isClipped: _vm.clippedNos.contains(c.id),
                          onLongPress: () => _showCommentActionSheet(ctx2, c),
                          onAnchorTap: (no) => _showAnchorPreview(no),
                          onImageTap: (url) {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => ImageViewerPage(url: url),
                              ),
                            );
                          },
                          onVote: (isPlus) async {
                            final no = c.id;
                            final commentId = 'vbox$no';
                            final success = await rateComment(widget.topicId, commentId, isPlus ? 1 : 0);
                            if (!mounted) return;
                            if (success) {
                              setState(() {
                                if (isPlus) {
                                  c.plus += 1;
                                } else {
                                  c.minus += 1;
                                }
                              });
                            }
                          },
                          checkAnchorAvailability: (no) => _vm.getCommentByNo(no) != null,
                        ),
                      );
                      if (shouldMeasure) {
                        return MeasureSize(
                          onChange: (sz) {
                            meas.onItemSize(i, sz.height, sc: sc);
                            // Reset flag after measurement to avoid repeated calls
                            meas.needsUpdate = false;
                          },
                          child: content,
                        );
                      } else {
                        return content;
                      }
                    },
                    childCount: pageItems.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                  ),
                ),

                // 末尾ページ以外なら「次の100件へ」ショートカット
                if (page < pageCount - 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CupertinoButton(
                          onPressed: () => _goToPage(page + 1),
                          child: const Text('次の100件へ'),
                        ),
                      ),
                    ),
                  ),

                // 最後のページでは「さらに読み込む」（手動トリガ、オプション）
                if (page == pageCount - 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CupertinoButton.filled(
                          onPressed: _loadingMore ? null : _fetchMoreDelta,
                          child: Text(_loadingMore ? '読み込み中…' : 'さらに読み込む'),
                        ),
                      ),
                    ),
                  ),

                // 末尾ページなら「読み込み中」プレースホルダ
                if (page == pageCount - 1 && _loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                  ),
                
                // 下部余白
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        );
      },
    );

    return PopScope(
      canPop: _allowPop,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // 戻る前に確実に保存
        _saveFromPage(_currentPage);
        await _vm.flushPendingScrollSave();

        if (mounted) {
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pop();
          });
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                'コメント: ${_vm.totalComments > 0 ? _vm.totalComments : widget.commentCount}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ★ 下書きがある場合のみ鉛筆マークを表示
              if (_vm.hasDraft)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _openPostDialog(),
                  child: const Icon(CupertinoIcons.pencil),
                ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showMenu,
                child: const Icon(CupertinoIcons.ellipsis),
              ),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: _vm.loading
              ? Center(child: PlatformHelper.buildLoadingIndicator())
              : Stack(
                  children: [
                    pageView,

                    // ページ移動用の左右ボタン
                    if (_pageCountLive > 1 && _hasPrev)
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            onPressed: _hasPrev ? _goPrevPage : null,
                            child: const Icon(CupertinoIcons.chevron_left, size: 22),
                          ),
                        ),
                      ),

                    if (_pageCountLive > 1 && _hasNext)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: CupertinoButton(
                            padding: const EdgeInsets.all(8),
                            onPressed: _hasNext ? _goNextPage : null,
                            child: const Icon(CupertinoIcons.chevron_right, size: 22),
                          ),
                        ),
                      ),

                    if (_pageCountLive > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentPage + 1} / $_pageCountLive',
                              style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
                            ),
                          ),
                        ),
                      ),

                  // （任意）復元前だけ「続きへ」チップを表示して手動復元も用意
                  if (_vm.savedCommentNo > 0 && !_restoredOnce)
                    Positioned(
                      top: 8, right: 8,
                      child: CupertinoButton.filled(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        onPressed: _restoring ? null : _tryRestoreIfNeeded,
                        child: Text('続き: No.${_vm.savedCommentNo}', style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                ],
              ),
      ),
    ));
  }

  Future<void> _handleClipAction(Comment comment) async {
    final no = comment.id;
    final isClipped = _vm.clippedNos.contains(no);
    
    if (isClipped) {
      await _vm.toggleClip(comment);
      if (mounted) setState(() {});
      return;
    }

    final labels = await getClipLabels();
    if (labels.length <= 1) {
      await _vm.toggleClip(comment, labelId: 0);
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('ラベルを選択してクリップ'),
        actions: labels.map((label) {
          final id = label['id'] as int;
          final name = label['name'] as String;
          final displayName = id == 0 && name.isEmpty ? '未分類' : name;
          return CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _vm.toggleClip(comment, labelId: id);
              if (mounted) setState(() {});
            },
            child: Text(displayName),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  void _showAnchorPreview(int no) {
    final c = _vm.getCommentByNo(no);
    if (c == null) {
      PlatformHelper.showSnackBar(context, 'コメントが見つからない');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (modalCtx) => AnchorPreviewSheet(
        comment: c,
        isClipped: _vm.clippedNos.contains(no),
        onAnchorTap: (targetNo) => _showAnchorPreview(targetNo),
        onImageTap: (url) {
          Navigator.of(modalCtx).push(
            CupertinoPageRoute(
              fullscreenDialog: true,
              builder: (_) => ImageViewerPage(url: url),
            ),
          );
        },
        onClipToggle: () async {
          await _handleClipAction(c);
          if (mounted) setState(() {});
        },
        onVote: (isPlus) async {
        if (c.isLocal) return;
        final commentId = 'vbox${c.id}';
        final success = await rateComment(widget.topicId, commentId, isPlus ? 1 : 0);
        if (!mounted) return;
        if (success) {
          setState(() {
            if (isPlus) {
              c.plus += 1;
            } else {
              c.minus += 1;
            }
          });
        }
      },
      ),
    );
  }



  void _showMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => TopicMenuSheet(
        onJump: _showJumpDialog,
        onReload: _vm.hardReload,
        onPost: _openPostDialog,
        onBrowser: () async {
          final url = Uri.parse('https://girlschannel.net/topics/${widget.topicId}/');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
      ),
    );
  }

  void _showJumpDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('コメントへジャンプ'),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'コメントNo (例: 100)',
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              final text = controller.text.trim();
              final no = int.tryParse(text);
              Navigator.pop(ctx);
              if (no != null && no > 0) {
                _tryRestoreIfNeeded(targetNo: no);
              }
            },
            child: const Text('ジャンプ'),
          ),
        ],
      ),
    );
  }



  void _showCommentActionSheet(BuildContext context, Comment c) {
    final no = c.id;
    final isClipped = _vm.clippedNos.contains(no);

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await _handleClipAction(c);
            },
            isDestructiveAction: isClipped,
            child: Text(isClipped ? 'クリップから削除する' : 'クリップに登録する'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _openPostDialog(initialText: '>>$no');
            },
            child: const Text('このコメントに返信'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  Future<void> _openPostDialog({String? initialText}) async {
    if (!mounted) return;

    final result = await Navigator.push<dynamic>(
      context,
      CupertinoPageRoute(
        builder: (_) => CommentComposePage(
          topicId: widget.topicId,
          title: widget.title,
          initialText: initialText,
        ),
      ),
    );

    if (!mounted) return;

    // ★ 戻ってきたら下書き状態を更新（保存したかもしれないし、削除したかもしれない）
    await _vm.checkDraft();

    if (result != null) {
      // 投稿されたのでコメント一覧を再読込
      await _vm.fetchDelta();
      
      // テキストが返ってきた場合は、その本文を持つコメントを探してクリップする
      if (result is String && result.isNotEmpty) {
        final postedText = result;
        Comment? target;
        // 最新のコメントから探す
        for (final c in _vm.comments.reversed) {
          if (c.text.trim() == postedText.trim()) {
            target = c;
            break;
          }
        }

        if (target != null) {
          // クリップ実行
          await _vm.toggleClip(target);
          if (mounted) {
            PlatformHelper.showSnackBar(context, 'コメントを投稿し、クリップしました');
          }
        } else {
           if (mounted) {
            PlatformHelper.showSnackBar(context, 'コメントを投稿しました');
          }
        }
      }
    }
  }



}
