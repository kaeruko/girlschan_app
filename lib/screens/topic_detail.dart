// --- UI専用: TopicDetailScreen ---
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import '../controllers/topic_detail_controller.dart';
import '../widgets/measure_size.dart';
import '../utils/variable_list_measurer.dart';
import 'comment_compose_page.dart';
import 'comment_post_webview.dart';
import 'image_viewer_page.dart';

class TopicDetailScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String posted_at;
  final int? initialJumpTo;
  final bool enableRefresh;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.posted_at,
    this.initialJumpTo,
    this.enableRefresh = true,
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
    )..addListener(_onVmChanged);

    // 初期化処理
    _vm.init().then((_) {
      if (!mounted) return;
      if (widget.initialJumpTo != null && widget.initialJumpTo! > 0) {
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

  List<dynamic> _itemsOfPage(int page, List<dynamic> all) {
  final start = page * _pageSize;
  final end = (start + _pageSize > all.length) ? all.length : (start + _pageSize);
  if (start >= all.length || start >= end) return <dynamic>[];
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
    // ★ 再入防止
    if (_restoredOnce && targetNo == null) {
      print('[復元] 自動復元済みのためスキップ');
      return; 
    }
    if (_vm.loading || _restoring) {
      print('[復元] loading=${_vm.loading}, restoring=$_restoring のためスキップ (target=$targetNo)');
      return;
    }
    _restoring = true;

    final savedNo = targetNo ?? _vm.savedCommentNo;
    print('[復元開始] savedNo=$savedNo (target=$targetNo)');
    if (savedNo <= 0) { 
      print('[復元中止] savedNo が 0 以下');
      _restoredOnce = true;
      _restoring = false;
      return; 
    }

    // まず、そのNoが入るまで差分取得
    print('[復元] ensureContainsNo($savedNo) 実行中...');
    await _vm.ensureContainsNo(savedNo);
    if (!mounted) {
      print('[復元] unmounted during ensureContainsNo');
      _restoring = false;
      return;
    }

    // index を特定してターゲットページへ
    final idx = _vm.indexByNo[savedNo];
    print('[復元] indexByNo[$savedNo] = $idx');
    if (idx == null) {
      print('[復元] index が見つからない、再スケジュール');
      _restoring = false;
      _scheduleTryRestore();
      return;
    }

    final targetPage = idx ~/ _pageSize;
    print('[復元] targetPage=$targetPage (idx=$idx)');

    _restoring = true;
    _restoreTargetPageNo = targetPage;
    _boostCacheDuringRestore = true;
    if (mounted) setState(() {}); // cacheExtent 反映

    // ★ PageView がビルドされるのを待つ
    await _waitForPageController();

    if (_pc.hasClients) {
      _pc.jumpToPage(targetPage);
      print('[復元] ページ遷移実行: $targetPage');
    } else {
      print('[復元] _pc has no clients! (wait failed?)');
    }

    // スクロール位置が attach されるのを確実に待つ
    await _waitForAttach(_scForPage(targetPage));

    // ページ遷移後、レイアウト完成を待つ
    await Future.delayed(const Duration(milliseconds: 50));

    // ★★★ ここから「概算ジャンプ」 + 「実測追従」を入れる
    // ページ内配列とメジャー/スクロールを準備
    final all0 = _vm.comments;
    final pageItems0 = _itemsOfPage(targetPage, all0);
    final meas = _measForPage(targetPage);
    meas.ensureCapacity(pageItems0.length);
    final sc = _scForPage(targetPage);

    // ページ内の savedNo のインデックスを特定
    final roughIndex =
        pageItems0.indexWhere((item) => (item['no'] as int?) == savedNo);
    if (roughIndex >= 0) {
      // 実測が入るまでこのインデックスを基準に追従するよう指示
      meas.markRestoreTargetIndex(roughIndex);
      // まずは fallbackHeight ベースの概算オフセットへジャンプ
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 16));
        if (!sc.hasClients) continue;
        final guess = meas.indexToOffset(roughIndex);
        try {
          sc.jumpTo(guess);
          print('[復元] 概算ジャンプ: index=$roughIndex, offset=$guess');
        } catch (_) {}
        break;
      }
    } else {
      print('[復元] ページ内に$savedNoが見つからない（直後に再試行へ）');
    }

    // ★ 該当行がビルドされるのを待ち、確実に ctx を得てから ensureVisible
    for (int attempt = 0; attempt < 60; attempt++) {
      final all = _vm.comments;
      final pageItems = _itemsOfPage(targetPage, all);
      
      // savedNo がこのページ内に存在するか確認
      final itemIndex = pageItems.indexWhere((item) => (item['no'] as int?) == savedNo);
      if (itemIndex == -1) {
        print('[復元] attempt=$attempt: ページ内に$savedNoが見つからない (pageItems.length=${pageItems.length})');
        await Future.delayed(const Duration(milliseconds: 16));
        continue;
      }

      // print('[復元] attempt=$attempt: pageItems内で$savedNoを発見 (itemIndex=$itemIndex)');

      // コメント番号をキーにしてコンテキストを取得
      final key = _vm.keyForCommentNo(savedNo);
      final ctx = key.currentContext;
      
      // print('[復元] key=$key, key.currentContext = $ctx');
      // print('[復元] _vm.commentKeys.length=${_vm.commentKeys.length}');
      
      if (ctx == null) {
        print('[復元] attempt=$attempt: currentContext がまだ null (key=$key)');
        // もし実測が進んでいれば、その都度ターゲットまでの概算位置に追従
        if (sc.hasClients) {
          final off = meas.indexToOffset(itemIndex);
          try { 
            sc.jumpTo(off); 
            // print('[復元] 追従ジャンプ: offset=$off');
          } catch (_) {}
        }
        await Future.delayed(const Duration(milliseconds: 16));
        continue;
      }

      print('[復元] currentContext を取得! ensureVisible 実行... (attempt=$attempt)');

      // 行頭を上端に揃える
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: Duration.zero,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );

      // 行内フラクション分だけ下にずらす
      final box = ctx.findRenderObject() as RenderBox?;
      final h = box?.size.height ?? 0.0;
      final frac = _vm.savedLocalFraction.clamp(0.0, 0.9999);
      print('[復元] box.height=$h, savedLocalFraction=$frac');
      
      if (h > 0 && frac > 0) {
        final sc2 = _scForPage(targetPage);
        if (sc2.hasClients) {
          final max = sc2.position.maxScrollExtent;
          final offset = (sc2.offset + h * frac).clamp(0.0, max);
          print('[復元] スクロール位置を調整: offset=$offset');
          sc2.jumpTo(offset);
        }
      }

      _vm.clearScrollFractionOnly();
      meas.markRestoreTargetIndex(null); // ★ 追従を解除
      _restoring = false;
      _restoredOnce = true;
      _boostCacheDuringRestore = false;
      _restoreTargetPageNo = null;
      if (mounted) setState(() {}); // cacheExtent を元に戻す

      // 復元直後の正しい位置で一度保存
      _saveFromPage(targetPage);
      print('[復元] 復元完了！');
      return;
    }

    // うまく行かなければ次フレームで再挑戦
    meas.markRestoreTargetIndex(null);
    _restoring = false;
    _boostCacheDuringRestore = false;
    _restoreTargetPageNo = null;
    if (mounted) setState(() {}); // cacheExtent を元に戻す
    _scheduleTryRestore();
  }


  // ==== UI ====
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
                // （必要なら）ページヘッダなどを SliverToBoxAdapter で入れてもOK
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx2, i) {
                      final c  = pageItems.isNotEmpty ? pageItems[i] : const {};
                      final no = (c['no'] as int?) ?? -1;
                      final globalIndex = page * _pageSize + i;

                      return MeasureSize(
                        onChange: (sz) => meas.onItemSize(i, sz.height, sc: sc),
                        child: _buildCommentItem(ctx2, c, globalIndex),
                      );
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
              ],
            ),
          ),
        );
      },
    );

    return CupertinoPageScaffold(
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
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showMenu,
          child: const Icon(CupertinoIcons.bars),
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
    );
  }

  void _showAnchorPreview(int no) {
    final c = _vm.getCommentByNo(no);
    if (c.isEmpty) {
      PlatformHelper.showSnackBar(context, 'コメントが見つからない');
      return;
    }

    final anchors    = (c['anchors'] as List?)?.cast<int>() ?? const <int>[];
    final revAnchors = (c['reverse_anchors'] as List?)?.cast<int>() ?? const <int>[];
    final body       = c['body'] as String? ?? '';
    final imgUrl     = (c['image_url'] as String?)?.trim();
    final hasImage   = imgUrl != null && imgUrl.isNotEmpty;
    final plus       = (c['plus'] as int?) ?? 0;
    final minus      = (c['minus'] as int?) ?? 0;
    final noText     = (c['no']?.toString()) ?? '?';
    final postedAt   = c['posted_at'] as String? ?? '';

    showCupertinoModalPopup(
      context: context,
      builder: (modalCtx) {
        // ローカル関数：アンカーのバッジ
        Widget anchorChips(List<int> list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Wrap(
                  spacing: 4,
                  children: list.map((n) {
                    final ok = _vm.getCommentByNo(n).isNotEmpty;
                    return GestureDetector(
                      onTap: () => _showAnchorPreview(n),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ok
                              ? CupertinoColors.systemBlue.withOpacity(0.1)
                              : CupertinoColors.systemGrey.withOpacity(0.1),
                          border: Border.all(
                            color: ok ? CupertinoColors.systemBlue : CupertinoColors.systemGrey3,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '>>$n',
                          style: TextStyle(
                            fontSize: 12,
                            color: ok ? CupertinoColors.systemBlue : CupertinoColors.secondaryLabel,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }

        // ローカル関数：逆アンカーのバッジ
        Widget revAnchorChips(List<int> list) {
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    children: list.take(5).map((n) {
                      return GestureDetector(
                        onTap: () => _showAnchorPreview(n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemOrange.withOpacity(0.1),
                            border: Border.all(color: CupertinoColors.systemOrange, width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '<<$n',
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
                if (list.length > 5)
                  Text(
                    ' +${list.length - 5}件',
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
                  ),
              ],
            ),
          );
        }

        final header = Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'No.$noText  $postedAt',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(4),
                onPressed: () => Navigator.pop(modalCtx),
                child: const Icon(CupertinoIcons.xmark, size: 20),
              ),
            ],
          ),
        );

        Widget? imageSection;
        if (hasImage) {
          imageSection = GestureDetector(
            onTap: () {
              Navigator.of(modalCtx).push(
                CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ImageViewerPage(url: imgUrl!),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imgUrl!,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                },
                errorBuilder: (context, error, stack) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(CupertinoIcons.photo, size: 40, color: CupertinoColors.systemGrey),
                  ),
                ),
              ),
            ),
          );
        }

        final reactionRow = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('＋$plus',  style: const TextStyle(color: Color(0xFFED6D74))),
                const SizedBox(width: 16),
                Text('−$minus', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
              ],
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(4),
              onPressed: () async {
                await _vm.toggleClip(c);
                if (!modalCtx.mounted) return;
                Navigator.pop(modalCtx);
              },
              child: Icon(
                _vm.clippedNos.contains(c['no']) ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                color: _vm.clippedNos.contains(c['no'])
                    ? CupertinoColors.systemRed
                    : CupertinoColors.secondaryLabel,
                size: 22,
              ),
            ),
          ],
        );

        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalCtx).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                children: [
                  header,
                  Expanded(
                    child: CupertinoScrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (anchors.isNotEmpty) anchorChips(anchors),
                            if (revAnchors.isNotEmpty) revAnchorChips(revAnchors),
                            Text(body, style: const TextStyle(fontSize: 15)),
                            if (imageSection != null) ...[
                              const SizedBox(height: 12),
                              imageSection,
                            ],
                            const SizedBox(height: 12),
                            reactionRow,
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
      },
    );
  }

  Widget _buildAnchorText(List<int> anchors) {
    if (anchors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Wrap(
            spacing: 4,
            children: anchors.map((no) {
              final referencedComment = _vm.getCommentByNo(no);
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
        ],
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
              if (!mounted) return;
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemGrey4),
              ),
              child: Row(
                children: [
                  if (thumbnail != null && thumbnail.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Image.network(
                        thumbnail,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 80),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isNotEmpty ? title : url,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: CupertinoColors.activeBlue,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (description != null && description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            url,
                            style: const TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.tertiaryLabel,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

  void _showMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showJumpDialog();
            },
            child: const Text('指定のコメントへ移動'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _openPostDialog();
            },
            child: const Text('コメントを投稿する'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final url = Uri.parse('https://girlschannel.net/topics/${widget.topicId}/');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('ブラウザで開く'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  void _showJumpDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('コメントへ移動'),
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
            child: const Text('移動'),
          ),
        ],
      ),
    );
  }



  Widget _buildCommentItem(BuildContext context, dynamic c, int i) {
    final no = (c['no'] as int?) ?? -1;
    final posted_at = c['posted_at'] ?? '';
    final name = c['name'] ?? '';
    final body = c['body'] ?? '';
    final plus = c['plus'] ?? 0;
    final minus = c['minus'] ?? 0;
    final anchors = List<int>.from(c['anchors'] ?? []);
    final reverseAnchors = List<int>.from(c['reverse_anchors'] ?? []);
    final urls = (c['urls'] as List?) ?? [];

    final innerWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No.$no  $name  $posted_at${c['isLocal'] == true ? ' （ローカル）' : ''}',
            style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
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
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(CupertinoIcons.photo, size: 40, color: CupertinoColors.secondaryLabel),
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
                final success = await rateComment(this.widget.topicId, commentId, 1);
                if (!mounted) return;
                if (success) setState(() => c['plus'] = (c['plus'] ?? 0) + 1);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('＋$plus', style: const TextStyle(color: CupertinoColors.systemRed)),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                if (c['isLocal'] == true) return;
                final commentId = 'vbox$no';
                final success = await rateComment(this.widget.topicId, commentId, -1);
                if (!mounted) return;
                if (success) setState(() => c['minus'] = (c['minus'] ?? 0) + 1);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('−$minus', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
              ),
            ),

          ],
        ),
      ],
    );

    return GestureDetector(
      onLongPress: () {
        showCupertinoModalPopup(
          context: context,
          builder: (context) => CupertinoActionSheet(
            actions: [
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.pop(context);
                  await _vm.toggleClip(Map<String, dynamic>.from(c));
                  if (mounted) setState(() {});
                },
                child: const Text('クリップに登録する'),
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
      },
      child: Container(
        key: no > 0 ? _vm.keyForCommentNo(no) : null,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: innerWidget,
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

    if (result != null) {
      // 投稿されたのでコメント一覧を再読込
      final addedCount = await _vm.fetchDelta();
      
      // テキストが返ってきた場合は、その本文を持つコメントを探してクリップする
      if (result is String && result.isNotEmpty) {
        final postedText = result;
        // 追加されたコメント（あるいは全コメント）から探す
        // 直近の投稿なので末尾付近にあるはず
        final candidates = _vm.comments.reversed.take(addedCount + 5); 
        
        Map<String, dynamic>? target;
        for (final c in candidates) {
          final body = c['body'] as String? ?? '';
          // 改行やスペースの揺れを考慮して、ある程度緩く比較するか、完全一致か
          // ここでは単純に trim して比較
          if (body.trim() == postedText.trim()) {
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

  Widget _buildPlusMinusGraph(int plus, int minus) {
    final total = plus + minus;
    if (total == 0) return const SizedBox.shrink();

    const double minWidth = 30.0;
    const double maxWidth = 300.0;
    const int capVotes = 1000;

    double barWidth;
    if (total >= capVotes) {
      barWidth = maxWidth;
    } else {
      final growthRatio = total / capVotes;
      barWidth = minWidth + (maxWidth - minWidth) * growthRatio;
    }

    return SizedBox(
      width: barWidth,
      child: Row(
        children: [
          if (plus > 0)
            Expanded(
              flex: plus,
              child: Container(
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFED6D74),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                ),
                alignment: Alignment.center,
                child: Text(plus.toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.white)),
              ),
            ),
          if (minus > 0)
            Expanded(
              flex: minus,
              child: Container(
                height: 20,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                ),
                alignment: Alignment.center,
                child: Text(minus.toString(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
