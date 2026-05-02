// --- UI専用: TopicDetailScreen ---
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/log.dart';

import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import '../controllers/topic_detail_controller.dart';
import '../controllers/topic_detail_shortcut_controller.dart';
import '../widgets/measure_size.dart';
import '../utils/variable_list_measurer.dart';
import 'comment_compose_page.dart';
import 'comment_post_webview.dart';
import 'image_viewer_page.dart';
import '../widgets/comment_tile.dart';
import '../widgets/anchor_preview_sheet.dart';
import '../widgets/topic_menu_sheet.dart';
import '../services/settings_service.dart';
import '../services/block_service.dart';
import '../widgets/common/app_spinner.dart';

// フィルタレベルの定義
enum CommentFilterLevel {
  all,      // 全表示
  positive, // プラス > マイナス
  popular,  // プラス > マイナス × 1.5
  legend,   // プラス > マイナス × 3.0
}

enum TopicDetailLayout {
  fullPage,
  embeddedPane,
}

class TopicDetailScreen extends StatelessWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String postedAt;
  final int? initialJumpTo;
  final bool enableRefresh;
  final bool saveReadPosition;
  final TopicDetailShortcutController? shortcutController;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.postedAt,
    this.initialJumpTo,
    this.enableRefresh = true,
    this.saveReadPosition = true,
    this.shortcutController,
  });

  @override
  Widget build(BuildContext context) {
    return TopicDetailView(
      topicId: topicId,
      title: title,
      commentCount: commentCount,
      postedAt: postedAt,
      initialJumpTo: initialJumpTo,
      enableRefresh: enableRefresh,
      saveReadPosition: saveReadPosition,
      layout: TopicDetailLayout.fullPage,
      shortcutController: shortcutController,
    );
  }
}

class TopicDetailPane extends StatelessWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String postedAt;
  final int? initialJumpTo;
  final bool enableRefresh;
  final bool saveReadPosition;
  final TopicDetailShortcutController? shortcutController;

  const TopicDetailPane({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.postedAt,
    this.initialJumpTo,
    this.enableRefresh = true,
    this.saveReadPosition = true,
    this.shortcutController,
  });

  @override
  Widget build(BuildContext context) {
    return TopicDetailView(
      topicId: topicId,
      title: title,
      commentCount: commentCount,
      postedAt: postedAt,
      initialJumpTo: initialJumpTo,
      enableRefresh: enableRefresh,
      saveReadPosition: saveReadPosition,
      layout: TopicDetailLayout.embeddedPane,
      shortcutController: shortcutController,
    );
  }
}

class TopicDetailView extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String postedAt;
  final int? initialJumpTo;
  final bool enableRefresh;
  final bool saveReadPosition;
  final TopicDetailLayout layout;
  final TopicDetailShortcutController? shortcutController;

  const TopicDetailView({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.postedAt,
    this.initialJumpTo,
    this.enableRefresh = true,
    this.saveReadPosition = true,
    required this.layout,
    this.shortcutController,
  });

  @override
  State<TopicDetailView> createState() => _TopicDetailViewState();
}

class _TopicDetailViewState extends State<TopicDetailView> {
  // ========== フィールド群 ==========
  late final TopicDetailController _vm;
  static const int _pageSize = 100;
  static const double _railBreakpoint = 900;
  static const double _railWidth = 320;
  final PageController _pc = PageController();
  final Map<int, ScrollController> _pageScroll = {};
  final Map<int, VariableListMeasurer> _pageMeas = {};
  final Map<int, double> _pageScrollOffsets = {}; // ページ内スクロール位置キャッシュ
  int _currentPage = 0;
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<int> _searchHitNos = [];
  int _searchHitIndex = -1;

  DateTime _lastFetchTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isPopping = false;
  bool _allowPop = false;

  bool _restoring = false;
  bool _restoredOnce = false;
  bool _loadingMore = false;
  int? _restoreTargetPageNo;
  bool _boostCacheDuringRestore = false;
  static const double _loadMoreThreshold = 300;

  // 現在のフィルター設定
  CommentFilterLevel _currentFilter = CommentFilterLevel.all;
  bool _showSearchRail = false;

  // 設定サービス
  final _settings = SettingsService();

  // 広告関連
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // ハイライトID
  int? _highlightedCommentId;
  int? _returnToCommentNo; // 戻るボタン用の元の位置

  // 非表示（通報済み）コメントID
  Set<int> _blockedCommentIds = {};

  // フィルタリングされたコメントリストを取得するゲッター
  List<Comment> get _displayComments {
    final base = _vm.comments.where((c) => !_blockedCommentIds.contains(c.id));
    if (_currentFilter == CommentFilterLevel.all) {
      return base.toList();
    }
    return base.where((c) {
      if (c.plus == 0) return false; // 荒らし対策（プラス0は除外）
      switch (_currentFilter) {
        case CommentFilterLevel.positive:
          return c.plus > c.minus;
        case CommentFilterLevel.popular:
          return c.plus > (c.minus * 1.5) && c.plus >= 5;
        case CommentFilterLevel.legend:
          return c.plus > (c.minus * 3.0) && c.plus >= 10;
        default:
          return true;
      }
    }).toList();
  }

  @override
  void didUpdateWidget(TopicDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shortcutController != widget.shortcutController) {
      oldWidget.shortcutController?.clear();
      _registerShortcutController(widget.shortcutController);
    }
    if (oldWidget.topicId == widget.topicId) {
      if (oldWidget.title != widget.title ||
          oldWidget.commentCount != widget.commentCount ||
          oldWidget.postedAt != widget.postedAt) {
        _vm.updateMetadata(
          title: widget.title,
          comments: widget.commentCount,
          postedAt: widget.postedAt,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _registerShortcutController(widget.shortcutController);
    _vm = TopicDetailController(
      topicId: widget.topicId,
      title: widget.title,
      commentCount: widget.commentCount,
      postedAt: widget.postedAt,
      enableRefresh: widget.enableRefresh,
      saveReadPosition: widget.saveReadPosition,
    )..addListener(_onVmChanged);

    _settings.addListener(_onSettingsChanged);

    _vm.init().then((_) {
      if (!mounted) return;
      if (widget.initialJumpTo != null && widget.initialJumpTo! > 0) {
        _vm.clearScrollFractionOnly();
        _tryRestoreIfNeeded(targetNo: widget.initialJumpTo);
      } else {
        _tryRestoreIfNeeded();
      }
    });

    _loadBannerAd();

    BlockService.loadBlockedComments(widget.topicId).then((ids) {
      if (!mounted) return;
      setState(() => _blockedCommentIds = ids);
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _searchFocusNode.dispose();
    _saveFromPage(_currentPage);
    for (final sc in _pageScroll.values) {
      sc.dispose();
    }
    _pc.dispose();
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _settings.removeListener(_onSettingsChanged);
    // clear() はここでは呼ばない。
    // 同一フレーム内で新トピックの initState() → bind() の後に旧トピックの dispose() が走るため、
    // clear() するとせっかくバインドされたコールバックが消えてしまう。
    // 詳細ペインが閉じた後にコールバックが呼ばれても sc.hasClients == false で早期リターンするので安全。
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});

    if (widget.initialJumpTo != null && widget.initialJumpTo! > 0) {
      return;
    }

    if (!_restoredOnce && !_vm.loading) {
      _scheduleTryRestore();
    }
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _registerShortcutController(TopicDetailShortcutController? controller) {
    controller?.bind(
      focusSearch: _handleSearchFocus,
      nextHit: () => _jumpToSearchHit(1),
      prevHit: () => _jumpToSearchHit(-1),
      nextUnread: _jumpToNextUnread,
      prevUnread: _jumpToPrevUnread,
      jumpToComment: _showJumpDialog,
      refresh: _fetchMoreDelta,
      scrollDown: _scrollDown,
      scrollUp: _scrollUp,
      scrollDownStep: _scrollDownStep,
      scrollUpStep: _scrollUpStep,
    );
  }

  /// スペースキーで画面1つ分下にスクロール
  void _scrollDown() {
    final sc = _scForPage(_currentPage);
    logd('📜 [TopicDetail] _scrollDown: page=$_currentPage, hasClients=${sc.hasClients}');
    if (!sc.hasClients) return;
    final viewportHeight = sc.position.viewportDimension;
    final target = (sc.offset + viewportHeight * 0.9).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }

  /// Shift+スペースで画面1つ分上にスクロール
  void _scrollUp() {
    final sc = _scForPage(_currentPage);
    if (!sc.hasClients) return;
    final viewportHeight = sc.position.viewportDimension;
    final target = (sc.offset - viewportHeight * 0.9).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }

  /// 矢印キーで小刻みに下スクロール
  void _scrollDownStep() {
    final sc = _scForPage(_currentPage);
    logd('📜 [TopicDetail] _scrollDownStep: page=$_currentPage, hasClients=${sc.hasClients}');
    if (!sc.hasClients) return;
    final target = (sc.offset + 120.0).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(target, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  /// 矢印キーで小刻みに上スクロール
  void _scrollUpStep() {
    final sc = _scForPage(_currentPage);
    if (!sc.hasClients) return;
    final target = (sc.offset - 120.0).clamp(0.0, sc.position.maxScrollExtent);
    sc.animateTo(target, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
  }

  // ========== ページング ==========
  int _pageCountFor(int total) => (total + _pageSize - 1) ~/ _pageSize;

  // _vm.comments ではなく _displayComments を基準にする
  int get _pageCountLive => _pageCountFor(_displayComments.length);
  
  bool get _hasPrev => _currentPage > 0;
  bool get _hasNext => _currentPage < _pageCountLive - 1;

  void _goToPage(int p) {
    final tgt = p.clamp(0, _pageCountLive > 0 ? _pageCountLive - 1 : 0);
    if (_pc.hasClients) {
      final sc = _scForPage(_currentPage);
      if (sc.hasClients) _pageScrollOffsets[_currentPage] = sc.offset;
      _saveFromPage(_currentPage);
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

  void _onPageScroll(int page) {
    if (_restoring) return;
    final sc = _scForPage(page);
    if (!sc.hasClients) return;

    // フィルタ中は追加ロードを禁止（整合性が取れないため）
    if (_currentFilter != CommentFilterLevel.all) return;

    final lastPage = _pageCountFor(_vm.comments.length) - 1;
    if (page == lastPage && !_loadingMore) {
      if (sc.position.extentAfter <= _loadMoreThreshold) {
        if (DateTime.now().difference(_lastFetchTime) < const Duration(seconds: 5)) {
          return;
        }
        _fetchMoreDelta();
      }
    }
  }

  Future<void> _fetchMoreDelta() async {
    logd('🔄 [TopicDetailScreen] _fetchMoreDelta called');
    if (_loadingMore) return;
    _lastFetchTime = DateTime.now();
    _loadingMore = true;
    try {
      final added = await _vm.fetchDelta();
      if (!mounted) return;
      if (added > 0) setState(() {});
    } finally {
      _loadingMore = false;
    }
  }

  // ========== スクロール位置の保存 ==========
  void _saveFromPage(int page) {
    if (_restoring) return;

    // 鉄の掟: 絞り込み中は位置情報を保存しない！
    if (_currentFilter != CommentFilterLevel.all) return;

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

  // ========== 復元ロジック ==========
  void _scheduleTryRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreIfNeeded();
    });
  }

  Future<void> _waitForAttach(ScrollController sc) async {
    for (int i = 0; i < 30; i++) {
      if (sc.hasClients && sc.position.hasPixels && sc.position.hasViewportDimension) return;
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _restorePageOffset(int page, double offset) async {
    final sc = _scForPage(page);
    await _waitForAttach(sc);
    if (!mounted) return;
    final clamped = offset.clamp(0.0, sc.position.maxScrollExtent);
    if (clamped > 0) sc.jumpTo(clamped);
  }

  Future<void> _waitForPageController() async {
    for (int i = 0; i < 30; i++) {
      if (_pc.hasClients && _pc.position.hasPixels) return;
      await Future.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _tryRestoreIfNeeded({int? targetNo}) async {
    final target = _startRestoreProcess(targetNo);
    if (target == null) return;

    try {
      final hasData = await _ensureDataAvailable(target);
      if (!hasData) return;

      // インデックスの特定を _displayComments 基準で行う
      final indexInList = _displayComments.indexWhere((c) => c.id == target);
      if (indexInList == -1) {
         return; 
      }
      final pageIndex = indexInList ~/ _pageSize;

      await _jumpToTargetPage(pageIndex);
      final success = await _seekAndScrollToComment(pageIndex, target);

      if (!success && _currentFilter == CommentFilterLevel.all) {
        _scheduleTryRestore();
      }
    } finally {
      _finishRestoreProcess(targetNo: target);
    }
  }

  int? _startRestoreProcess(int? targetNo) {
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

  void _finishRestoreProcess({int? targetNo}) {
    _restoring = false;
    _boostCacheDuringRestore = false;
    _restoreTargetPageNo = null;

    if (mounted) setState(() {});
    _measForPage(_currentPage).needsUpdate = true;
  }

  Future<bool> _ensureDataAvailable(int targetNo) async {
    // フィルタリング中はAPIフェッチを行わない
    if (_currentFilter != CommentFilterLevel.all) {
      return _displayComments.any((c) => c.id == targetNo);
    }

    await _vm.ensureContainsNo(targetNo);
    if (!mounted) return false;
    return _vm.indexByNo.containsKey(targetNo);
  }

  Future<void> _jumpToTargetPage(int pageIndex) async {
    _restoreTargetPageNo = pageIndex;
    _boostCacheDuringRestore = true;
    if (mounted) setState(() {});

    await _waitForPageController();
    if (_pc.hasClients && _pc.page?.round() != pageIndex) {
      _pc.jumpToPage(pageIndex);
    }
    await _waitForAttach(_scForPage(pageIndex));
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<bool> _seekAndScrollToComment(int pageIndex, int targetNo) async {
    final sc = _scForPage(pageIndex);
    final meas = _measForPage(pageIndex);
    
    // 概算ジャンプも _displayComments を使用
    _performApproximateJump(pageIndex, targetNo, sc, meas);

    for (int attempt = 0; attempt < 60; attempt++) {
      if (!mounted) return false;
      final found = await _tryAlignVisible(targetNo, pageIndex);
      if (found) {
        _saveFromPage(pageIndex);
        _restoredOnce = true;
        return true; 
      }
      _adjustApproximatePosition(pageIndex, targetNo, sc, meas);
      await Future.delayed(const Duration(milliseconds: 16));
    }
    return false;
  }

  void _performApproximateJump(int page, int targetNo, ScrollController sc, VariableListMeasurer meas) {
    // 現在の表示リストを使用
    final all = _displayComments;
    final pageItems = _itemsOfPage(page, all);
    final roughIndex = pageItems.indexWhere((item) => item.id == targetNo);

    if (roughIndex >= 0) {
      meas.markRestoreTargetIndex(roughIndex);
      if (sc.hasClients) {
        try {
          final guess = meas.indexToOffset(roughIndex);
          sc.jumpTo(guess);
        } catch (_) {}
      }
    }
  }

  Future<bool> _tryAlignVisible(int targetNo, int pageIndex) async {
    final key = _vm.keyForCommentNo(targetNo);
    final ctx = key.currentContext;

    if (ctx == null) return false;

    await Scrollable.ensureVisible(
      ctx,
      alignment: 0.0,
      duration: Duration.zero,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );

    if (!mounted) return false;
    if (key.currentContext == null) return false;

    // 全表示時のみ、保存されていたFraction（途中位置）を反映する
    if (_currentFilter == CommentFilterLevel.all) {
      final validCtx = key.currentContext;
      if (validCtx == null) return false;

      // ignore: use_build_context_synchronously
      final box = validCtx.findRenderObject() as RenderBox?;
      final h = box?.size.height ?? 0.0;
      final frac = _vm.savedLocalFraction.clamp(0.0, 0.9999);
      if (h > 0 && frac > 0) {
        final sc = _scForPage(pageIndex);
        if (sc.hasClients) {
          final offset = (sc.offset + h * frac).clamp(0.0, sc.position.maxScrollExtent);
          sc.jumpTo(offset);
        }
      }
    }

    _vm.clearScrollFractionOnly();
    _measForPage(pageIndex).markRestoreTargetIndex(null);
    return true;
  }

  void _adjustApproximatePosition(int page, int targetNo, ScrollController sc, VariableListMeasurer meas) {
     _performApproximateJump(page, targetNo, sc, meas);
  }

  // ========== UIアクション ==========

  void _showSearchDialog() async {
    final int? selectedNo = await showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) => TopicSearchModal(
        allComments: _vm.comments,
        onQueryChanged: _updateSearchQuery,
      ),
    );

    if (!mounted) return;
    if (selectedNo != null && selectedNo > 0) {
      _jumpToCommentNo(selectedNo);
    }
  }

  void _handleSearchAction(double width) {
    if (width >= _railBreakpoint) {
      setState(() => _showSearchRail = !_showSearchRail);
      return;
    }
    _showSearchDialog();
  }

  void _handleSearchFocus() {
    final width = MediaQuery.of(context).size.width;
    if (width >= _railBreakpoint) {
      if (!_showSearchRail) {
        setState(() => _showSearchRail = true);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
      return;
    }
    _showSearchDialog();
  }

  void _updateSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
        _searchHitNos = [];
        _searchHitIndex = -1;
      });
      return;
    }

    final lowerQuery = trimmed.toLowerCase();
    final hits = _vm.comments.where((c) {
      return c.body.toLowerCase().contains(lowerQuery) ||
          (c.id.toString() == lowerQuery);
    }).map((c) => c.id).toList();

    setState(() {
      if (_searchQuery != trimmed) {
        _searchHitIndex = -1;
      }
      _searchQuery = trimmed;
      _searchHitNos = hits;
      if (_searchHitIndex >= _searchHitNos.length) {
        _searchHitIndex = -1;
      }
    });
  }

  void _jumpToSearchHit(int delta) {
    if (_searchQuery.isEmpty || _searchHitNos.isEmpty) {
      PlatformHelper.showSnackBar(context, '検索結果がありません');
      return;
    }
    final count = _searchHitNos.length;
    final nextIndex = _searchHitIndex == -1
        ? (delta > 0 ? 0 : count - 1)
        : (_searchHitIndex + delta) % count;
    _searchHitIndex = nextIndex < 0 ? count - 1 : nextIndex;
    _jumpToCommentNo(_searchHitNos[_searchHitIndex]);
  }

  int? _currentVisibleCommentNo() {
    final all = _vm.comments;
    if (all.isEmpty) return null;
    final pageItems = _itemsOfPage(_currentPage, all);
    if (pageItems.isEmpty) return null;
    final sc = _scForPage(_currentPage);
    if (!sc.hasClients) return null;
    final meas = _measForPage(_currentPage);
    meas.ensureCapacity(pageItems.length);
    final idx = meas.offsetToIndex(sc.offset, pageItems.length);
    final safe = idx.clamp(0, pageItems.length - 1);
    return pageItems[safe].id;
  }

  void _ensureAllFilterThen(VoidCallback action) {
    if (_currentFilter == CommentFilterLevel.all) {
      action();
      return;
    }
    setState(() {
      _currentFilter = CommentFilterLevel.all;
      _currentPage = 0;
    });
    if (_pc.hasClients) {
      _pc.jumpToPage(0);
    }
    PlatformHelper.showSnackBar(context, '全件表示に戻しました');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        action();
      }
    });
  }

  void _jumpToCommentNo(int no) {
    final hasTarget = _displayComments.any((c) => c.id == no);
    if (hasTarget) {
      _tryRestoreIfNeeded(targetNo: no);
      return;
    }
    _ensureAllFilterThen(() => _tryRestoreIfNeeded(targetNo: no));
  }

  void _jumpToNextUnread() {
    _jumpToUnread(forward: true);
  }

  void _jumpToPrevUnread() {
    _jumpToUnread(forward: false);
  }

  void _jumpToUnread({required bool forward}) {
    _ensureAllFilterThen(() {
      final savedNo = _vm.savedCommentNo;
      final comments = _vm.comments;
      if (comments.isEmpty || savedNo <= 0) {
        PlatformHelper.showSnackBar(context, '未読コメントがありません');
        return;
      }
      final unread = comments.where((c) => c.id > savedNo).toList();
      if (unread.isEmpty) {
        PlatformHelper.showSnackBar(context, '未読コメントがありません');
        return;
      }

      final currentNo = _currentVisibleCommentNo();
      int targetNo;
      if (forward) {
        final baseNo = currentNo != null && currentNo > savedNo ? currentNo : savedNo;
        targetNo = unread.firstWhere(
          (c) => c.id > baseNo,
          orElse: () => unread.first,
        ).id;
      } else {
        if (currentNo == null || currentNo <= savedNo) {
          targetNo = unread.last.id;
        } else {
          targetNo = unread.lastWhere(
            (c) => c.id < currentNo,
            orElse: () => unread.last,
          ).id;
        }
      }
      _jumpToCommentNo(targetNo);
    });
  }

  void _showFilterSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('いいね数で絞り込み'),
        message: const Text('表示をフィルタリングします'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _currentFilter == CommentFilterLevel.all,
            onPressed: () {
              Navigator.pop(context);
              _onFilterChanged(CommentFilterLevel.all);
            },
            child: const Text('なし'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _currentFilter == CommentFilterLevel.positive,
            onPressed: () {
              Navigator.pop(context);
              _onFilterChanged(CommentFilterLevel.positive);
            },
            child: const Text('普通🍙'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _currentFilter == CommentFilterLevel.popular,
            onPressed: () {
              Navigator.pop(context);
              _onFilterChanged(CommentFilterLevel.popular);
            },
            child: const Text('大盛り🍛'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _currentFilter == CommentFilterLevel.legend,
            onPressed: () {
              Navigator.pop(context);
              _onFilterChanged(CommentFilterLevel.legend);
            },
            child: const Text('特盛り🍲'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  void _onFilterChanged(CommentFilterLevel newFilter) {
    int? targetNo;
    
    final currentList = _displayComments; 
    final pageItems = _itemsOfPage(_currentPage, currentList);
    
    if (pageItems.isNotEmpty) {
      targetNo = pageItems.first.id;
    }

    setState(() {
      _currentFilter = newFilter;
      _currentPage = 0;
    });
    
    if (_pc.hasClients) {
      _pc.jumpToPage(0);
    }

    if (targetNo != null && targetNo > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryRestoreIfNeeded(targetNo: targetNo);
      });
    }

    final count = _displayComments.length;
    final msg = _currentFilter == CommentFilterLevel.all 
        ? '全件表示に戻しました' 
        : '$count件に絞り込みました';
    PlatformHelper.showSnackBar(context, msg);
  }

  // ★★★ 追加: 返信一覧を表示するシート ★★★
  void _showRepliesList(List<int> replyIds) {
    final replies = replyIds
        .map((id) => _vm.getCommentByNo(id))
        .whereType<Comment>()
        .toList();

    if (replies.isEmpty) {
      PlatformHelper.showSnackBar(context, '返信コメントが見つかりません');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ReplyListSheet(
        replies: replies,
        onAnchorTap: (no, pos) => _showAnchorPreview(no, tapPos: pos),
        onImageTap: (url) {
          Navigator.of(ctx).push(
            CupertinoPageRoute(
              fullscreenDialog: true,
              builder: (_) => ImageViewerPage(url: url),
            ),
          );
        },
        settings: _settings,
        // ★ ここで再帰呼び出しを可能にする（自分自身を呼ぶ）
        onRepliesTap: (ids) => _showRepliesList(ids),
        onGoToComment: (no) => _jumpToCommentNo(no),
      ),
    );
  }

  void _loadBannerAd() {
    // デスクトップなどは広告非対応のためスキップ
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-1701253412237513/7949216085',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
          });
          logd('✅ [TopicDetail] 広告読み込み成功');
        },
        onAdFailedToLoad: (ad, error) {
          logd('❌ [TopicDetail] 広告読み込み失敗: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  String _subtitleText(List<Comment> items) {
    return _currentFilter == CommentFilterLevel.all
        ? '${widget.postedAt} • コメント: ${_vm.totalComments > 0 ? _vm.totalComments : widget.commentCount}'
        : '絞り込み中: ${items.length}件を表示';
  }

  TextStyle _subtitleTextStyle() {
    return TextStyle(
      fontSize: 11,
      color: _currentFilter == CommentFilterLevel.all
          ? CupertinoColors.secondaryLabel
          : CupertinoColors.systemOrange,
      fontWeight: _currentFilter == CommentFilterLevel.all
          ? FontWeight.normal
          : FontWeight.bold,
    );
  }

  Widget _buildHeaderTitle(List<Comment> items, {required CrossAxisAlignment alignment}) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          _subtitleText(items),
          style: _subtitleTextStyle(),
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    EdgeInsets padding = const EdgeInsets.all(6),
  }) {
    return CupertinoButton(
      padding: padding,
      minSize: 0,
      onPressed: onPressed,
      child: Icon(icon, size: 20),
    );
  }

  List<Widget> _buildHeaderActions({
    required bool includeFilter,
    required double availableWidth,
    EdgeInsets padding = const EdgeInsets.all(6),
  }) {
    return [
      _buildHeaderButton(
        icon: CupertinoIcons.search,
        onPressed: () => _handleSearchAction(availableWidth),
        padding: padding,
      ),
      if (includeFilter)
        _buildHeaderButton(
          icon: CupertinoIcons.slider_horizontal_3,
          onPressed: _showFilterSheet,
          padding: padding,
        ),
      if (_vm.hasDraft)
        _buildHeaderButton(
          icon: CupertinoIcons.pencil,
          onPressed: () => _openPostDialog(),
          padding: padding,
        ),
      _buildHeaderButton(
        icon: CupertinoIcons.arrow_clockwise,
        onPressed: _vm.hardReload,
        padding: padding,
      ),
      _buildHeaderButton(
        icon: CupertinoIcons.ellipsis,
        onPressed: _showMenu,
        padding: padding,
      ),
    ];
  }

  Widget _buildEmbeddedHeader(List<Comment> items) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildHeaderTitle(
              items,
              alignment: CrossAxisAlignment.start,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildHeaderActions(
              includeFilter: true,
              availableWidth: width,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<Comment> items, Widget pageView) {
    if (_vm.loading) {
      return const Center(child: AppSpinner(size: 32, showLabel: true));
    }
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.slash_circle, size: 48, color: CupertinoColors.systemGrey3),
            const SizedBox(height: 16),
            Text(
              _currentFilter == CommentFilterLevel.all
                  ? 'コメントがありません'
                  : '条件に合うコメントがありません',
              style: const TextStyle(color: CupertinoColors.systemGrey),
            ),
            if (_currentFilter != CommentFilterLevel.all)
              CupertinoButton(
                child: const Text('フィルターを解除'),
                onPressed: () => _onFilterChanged(CommentFilterLevel.all),
              ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        pageView,
        if (_pageCountLive > 1 && _hasPrev)
          Positioned(
            left: 8, top: 0, bottom: 0,
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
            right: 8, top: 0, bottom: 0,
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
            bottom: 8, left: 0, right: 0,
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
        if (_vm.savedCommentNo > 0 && !_restoredOnce && _currentFilter == CommentFilterLevel.all)
          Positioned(
            top: 8, right: 8,
            child: CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onPressed: _restoring ? null : _tryRestoreIfNeeded,
              child: Text('続き: No.${_vm.savedCommentNo}', style: const TextStyle(fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Widget _buildContentColumn(List<Comment> items, Widget pageView) {
    return Column(
      children: [
        Expanded(child: _buildMainContent(items, pageView)),
        if (_isAdLoaded && _bannerAd != null)
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
      ],
    );
  }

  Widget _wrapWithShortcuts(Widget child) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _handleSearchFocus,
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () => _jumpToSearchHit(1),
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true, shift: true): () => _jumpToSearchHit(-1),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true): _jumpToNextUnread,
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true): _jumpToPrevUnread,
        const SingleActivator(LogicalKeyboardKey.keyJ, meta: true): _showJumpDialog,
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _displayComments;
    final pageCount = _pageCountFor(items.length);
    final allowPopGesture = widget.layout == TopicDetailLayout.fullPage;
    final width = MediaQuery.of(context).size.width;
    final canShowRail = width >= _railBreakpoint;
    final showRail = canShowRail && _showSearchRail;

    Widget pageView = PageView.builder(
      controller: _pc,
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      onPageChanged: (p) {
        _saveFromPage(_currentPage);
        final savedOffset = _pageScrollOffsets[p];
        setState(() => _currentPage = p);
        if (savedOffset != null && savedOffset > 0 && !_restoring) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restorePageOffset(p, savedOffset);
          });
        }
      },
      itemCount: pageCount > 0 ? pageCount : 1,
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
                  ? 50000.0 : 1200.0,
              // macOSではバウンス無効（連続スワイプ対策）、それ以外はバウンス有効
              physics: PlatformHelper.isDesktop
                  ? const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
                  : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx2, i) {
                      final Comment c = pageItems.isNotEmpty ? pageItems[i] : Comment(id: 0, postedAt: '', body: '', plus: 0, minus: 0);
                      final bool shouldMeasure = _restoring || meas.needsUpdate;
                      Widget content = Container(
                        key: c.id > 0 ? _vm.keyForCommentNo(c.id) : null,
                        child: CommentTile(
                          comment: c,
                          highlighted: c.id == _highlightedCommentId,
                          userStatus: _vm.getUserStatus(c.id),
                          onLongPress: () => _showCommentActionSheet(ctx2, c),
                          onAnchorTap: (no, pos) => _showAnchorPreview(no, tapPos: pos),
                          onImageTap: (url) {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => ImageViewerPage(url: url),
                              ),
                            );
                          },
                          // ★ 返信ボタンが押された時の処理
                          onRepliesTap: (ids) => _showRepliesList(ids), 

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
                          fontSize: _settings.fontSize,
                        ),
                      );
                      if (shouldMeasure) {
                        return MeasureSize(
                          onChange: (sz) {
                            meas.onItemSize(i, sz.height, sc: sc);
                            meas.needsUpdate = false;
                          },
                          child: content,
                        );
                      } else {
                        return content;
                      }
                    },
                    childCount: pageItems.length,
                  ),
                ),
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
                if (page == pageCount - 1 && _currentFilter == CommentFilterLevel.all)
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
                if (page == pageCount - 1 && _loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        );
      },
    );

    if (allowPopGesture) {
      pageView = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 && notification is ScrollUpdateNotification) {
            if (notification.metrics.pixels < -70 && !_isPopping) {
              if (notification.dragDetails != null) {
                _isPopping = true;
                Navigator.of(context).maybePop();
                return true;
              }
            }
          }
          return false;
        },
        child: pageView,
      );
    }

    final contentColumn = _buildContentColumn(items, pageView);
    final contentRow = Row(
      children: [
        Expanded(child: contentColumn),
        if (showRail)
          Container(
            width: _railWidth,
            decoration: BoxDecoration(
              color: _settings.backgroundColor,
              border: const Border(
                left: BorderSide(color: CupertinoColors.separator),
              ),
            ),
            child: TopicSearchRail(
              allComments: _vm.comments,
              currentFilter: _currentFilter,
              onFilterChanged: _onFilterChanged,
              onJumpToComment: _jumpToCommentNo,
              currentPage: _currentPage,
              pageCount: _pageCountLive,
              hasPrev: _hasPrev,
              hasNext: _hasNext,
              onPrevPage: _goPrevPage,
              onNextPage: _goNextPage,
              settings: _settings,
              onClose: () => setState(() => _showSearchRail = false),
              onQueryChanged: _updateSearchQuery,
              searchFocusNode: _searchFocusNode,
            ),
          ),
      ],
    );

    if (widget.layout == TopicDetailLayout.embeddedPane) {
      return _wrapWithShortcuts(
        Container(
          color: _settings.backgroundColor,
          child: Column(
            children: [
              _buildEmbeddedHeader(items),
              Expanded(child: contentRow),
            ],
          ),
        ),
      );
    }

    return _wrapWithShortcuts(
      PopScope(
        canPop: _allowPop,
        onPopInvoked: (didPop) async {
          if (didPop) return;
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
          backgroundColor: _settings.backgroundColor,
          navigationBar: CupertinoNavigationBar(
            middle: _buildHeaderTitle(
              items,
              alignment: CrossAxisAlignment.center,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildHeaderActions(
                includeFilter: false,
                availableWidth: width,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: contentRow,
          ),
        ),
      ),
    );
  }

  Future<void> _handleClipAction(Comment comment) async {
    final no = comment.id;
    final status = _vm.getUserStatus(no);
    final isClipped = status != CommentUserStatus.none;
    
    if (isClipped) {
      await _vm.toggleClip(comment);
      if (mounted) setState(() {});
      return;
    }

    final labels = await getClipLabels();
    
    // マイコメント以外のラベル（ユーザーが選択可能なラベル）を抽出
    final selectableLabels = labels.where((l) => l['name'] != kMyCommentsLabelName).toList();
    
    // 選択可能なラベルが1つ以下（未分類のみ）の場合は選択画面を出さない
    if (selectableLabels.length <= 1) {
      await _vm.toggleClip(comment, labelId: 0);
      if (mounted) setState(() {});
      return;
    }

    if (!mounted) return;
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('ラベルを選択してクリップ'),
        actions: selectableLabels.map((label) {
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

  void _showAnchorPreview(int no, {Offset? tapPos}) {
    // ローカル検索のみ
    final c = _vm.getCommentByNo(no);
    if (c == null) {
      PlatformHelper.showSnackBar(context, '読み込まれていないコメントです');
      return;
    }

    // デスクトップで位置情報がある場合はPopover表示
    if (PlatformHelper.isDesktop && tapPos != null) {
      _showDesktopAnchorPopover(c, tapPos);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) => AnchorPreviewSheet(
        comment: c,
        isClipped: _vm.getUserStatus(no) != CommentUserStatus.none,
        onAnchorTap: (targetNo) {
           Navigator.pop(modalCtx); // 一旦閉じてから次へ（遷移を見やすく）
           _showAnchorPreview(targetNo);
        },
        onGoTo: () => _goToAnchor(no, fromPreview: true),
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

  void _showDesktopAnchorPopover(Comment c, Offset tapPos) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black12,
        pageBuilder: (context, _, __) {
          const width = 360.0;
          const height = 400.0; // 少し大きめに確保
          final size = MediaQuery.of(context).size;
          
          // 画面内に収まるようにクランプ
          // タップ位置の少し右下にだしたいが、はみ出るなら調整
          double left = tapPos.dx + 16;
          double top = tapPos.dy + 16;

          // 右端チェック
          if (left + width > size.width - 16) {
             left = size.width - width - 16;
          }
          if (left < 16) left = 16;
          
          // 下端チェック
          if (top + height > size.height - 16) {
             top = size.height - height - 16;
             // それでも上にはみ出るなら上にずらす等の調整も可能だが、
             // 一旦クランプで対応
          }
          if (top < 16) top = 16;

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  // MaterialType.transparency ではなく色指定
                  color: CupertinoColors.systemBackground,
                  child: Container(
                    width: width,
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: AnchorPreviewSheet(
                      comment: c,
                      isClipped: _vm.getUserStatus(c.id) != CommentUserStatus.none,
                      onAnchorTap: (targetNo) {
                        Navigator.pop(context); // 閉じて次へ
                        // 少し遅延させて閉じるアニメーションと干渉しないようにしてもいいが
                        // ここでは直で呼ぶ（次のPopoverが出る）
                        // タップ位置は不明になるので、次は中央orBottomSheetになるかもしれないが
                        // "Popover内のタップ"の位置を取ればPopoverチェーン可能。
                        // 今回はシンプルに offset なしで呼んでみる（スマホ的挙動になるか、nullチェックで分岐）
                        // ※Desktopなら位置が欲しいが、連鎖プレビューは中央でも許容範囲？
                        //   -> 要望通りシンプルに実装するなら、ここも位置を取りたいが
                        //      AnchorPreviewSheetのonAnchorTapはまだintのみ。
                        //      「次へ」はBottom Sheetで妥協するか、
                        //      AnchorPreviewSheetもGestureDetectorで囲って位置を取るか。
                        //      ここでは一旦「位置なし」で呼ぶ。（Bottom Sheetになる）
                         _showAnchorPreview(targetNo); 
                      },
                      onGoTo: () => _goToAnchor(c.id, fromPreview: true),
                      onImageTap: (url) {
                         Navigator.of(context).push(
                          CupertinoPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => ImageViewerPage(url: url),
                          ),
                        );
                      },
                      onClipToggle: () async {
                        await _handleClipAction(c);
                        // 親(TopicDetail)の更新が必要なら通知が必要だが、
                        // ここではsetStateできないので、閉じた後に反映されるか、
                        // あるいはVM経由で変わる。
                        // 簡易実装としてVM操作のみ。
                      },
                       onVote: (isPlus) async {
                        if (c.isLocal) return;
                        final commentId = 'vbox${c.id}';
                        await rateComment(widget.topicId, commentId, isPlus ? 1 : 0);
                        // UI反映は省略(閉じる前提ならOK)
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _goToAnchor(int targetNo, {bool fromPreview = false}) {
    if (fromPreview) {
      Navigator.pop(context); // プレビューを閉じる
    }

    // 元の位置を保存（戻るボタン用）
    final currentNo = _currentVisibleCommentNo();
    if (currentNo != null) {
      _returnToCommentNo = currentNo;
    }

    // ジャンプ
    _jumpToCommentNo(targetNo);

    // ハイライト演出
    setState(() => _highlightedCommentId = targetNo);
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _highlightedCommentId = null);
      }
    });

    // 戻るアクションのSnackBarを表示
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('移動しました'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '元の位置に戻る',
          onPressed: () {
            if (_returnToCommentNo != null) {
              _jumpToCommentNo(_returnToCommentNo!);
            }
          },
        ),
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
        onFilter: _showFilterSheet,
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
                _jumpToCommentNo(no);
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
    final isClipped = _vm.isClipped(no);

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
              _openPostDialog(initialText: '>>$no', repliedComment: c);
            },
            child: const Text('このコメントに返信'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await BlockService.addBlockedComment(widget.topicId, no);
              if (!mounted) return;
              setState(() => _blockedCommentIds = {..._blockedCommentIds, no});
              final url = Uri.parse(
                'https://docs.google.com/forms/d/e/1FAIpQLSdD0bu4VxiA6ZR_ehbi-Gs9w_QanfGhjA7dnTjiVWdMqBZecA/viewform?usp=publish-editor',
              );
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('通報して非表示にする'),
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

  Future<void> _openPostDialog({String? initialText, Comment? repliedComment}) async {
    if (!mounted) return;

    final result = await Navigator.push<dynamic>(
      context,
      CupertinoPageRoute(
        builder: (_) => CommentComposePage(
          topicId: widget.topicId,
          title: widget.title,
          initialText: initialText,
          repliedComment: repliedComment,
        ),
      ),
    );

    if (!mounted) return;
    await _vm.checkDraft();

    if (result != null) {
      await _vm.fetchDelta();
      
      if (result is String && result.isNotEmpty) {
        final postedText = result;
        Comment? target;
        for (final c in _vm.comments.reversed) {
          if (c.body.trim() == postedText.trim()) {
            target = c;
            break;
          }
        }

        if (target != null) {
          final labelId = _vm.myCommentLabelId ?? 0;
          await _vm.toggleClip(target, labelId: labelId);
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

class TopicSearchModal extends StatefulWidget {
  final List<Comment> allComments;
  final ValueChanged<String>? onQueryChanged;

  const TopicSearchModal({
    super.key,
    required this.allComments,
    this.onQueryChanged,
  });

  @override
  State<TopicSearchModal> createState() => _TopicSearchModalState();
}

class _TopicSearchModalState extends State<TopicSearchModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Comment> _filteredComments = [];
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _filteredComments = []; 
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.onQueryChanged?.call(query);
    if (query.isEmpty) {
      setState(() => _filteredComments = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredComments = widget.allComments.where((c) {
        return c.body.toLowerCase().contains(lowerQuery) ||
               (c.id.toString() == lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('閉じる'),
          onPressed: () => Navigator.pop(context),
        ),
        middle: const Text('トピ内検索'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CupertinoSearchTextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                placeholder: 'キーワードまたはNoを入力',
              ),
            ),
            Expanded(
              child: _searchCtrl.text.isEmpty
                  ? const Center(
                      child: Text(
                        'ロード済みのコメントから検索します',
                        style: TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    )
                  : _filteredComments.isEmpty
                      ? const Center(
                          child: Text('見つかりませんでした'),
                        )
                      : ListView.separated(
                          itemCount: _filteredComments.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = _filteredComments[i];
                            return Material( 
                              color: Colors.transparent,
                              child: ListTile(
                                title: Text(
                                  '${c.id}. ${c.body.replaceAll('\n', ' ')}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                trailing: const Icon(CupertinoIcons.forward, size: 16),
                                onTap: () {
                                  Navigator.pop(context, c.id);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopicSearchRail extends StatefulWidget {
  final List<Comment> allComments;
  final CommentFilterLevel currentFilter;
  final ValueChanged<CommentFilterLevel> onFilterChanged;
  final ValueChanged<int> onJumpToComment;
  final int currentPage;
  final int pageCount;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final SettingsService settings;
  final VoidCallback? onClose;
  final ValueChanged<String>? onQueryChanged;
  final FocusNode? searchFocusNode;

  const TopicSearchRail({
    super.key,
    required this.allComments,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.onJumpToComment,
    required this.currentPage,
    required this.pageCount,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrevPage,
    required this.onNextPage,
    required this.settings,
    this.onClose,
    this.onQueryChanged,
    this.searchFocusNode,
  });

  @override
  State<TopicSearchRail> createState() => _TopicSearchRailState();
}

class _TopicSearchRailState extends State<TopicSearchRail> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Comment> _filteredComments = [];

  @override
  void didUpdateWidget(TopicSearchRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allComments != widget.allComments && _searchCtrl.text.isNotEmpty) {
      _onSearchChanged(_searchCtrl.text);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.onQueryChanged?.call(query);
    if (query.isEmpty) {
      setState(() => _filteredComments = []);
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredComments = widget.allComments.where((c) {
        return c.body.toLowerCase().contains(lowerQuery) ||
            (c.id.toString() == lowerQuery);
      }).toList();
    });
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFilterButton(CommentFilterLevel level, String label, IconData icon) {
    final isSelected = widget.currentFilter == level;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey5,
      onPressed: () => widget.onFilterChanged(level),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? CupertinoColors.white : CupertinoColors.black),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? CupertinoColors.white : CupertinoColors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredComments;
    return Container(
      color: widget.settings.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '検索サイドレール',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.onClose != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onClose,
                    child: const Icon(CupertinoIcons.xmark_circle_fill),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CupertinoSearchTextField(
              controller: _searchCtrl,
              focusNode: widget.searchFocusNode,
              onChanged: _onSearchChanged,
              placeholder: 'キーワード / No',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSectionTitle('フィルタプリセット'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterButton(CommentFilterLevel.all, 'すべて', CupertinoIcons.list_bullet),
                _buildFilterButton(CommentFilterLevel.positive, '普通', CupertinoIcons.hand_thumbsup),
                _buildFilterButton(CommentFilterLevel.popular, '人気', CupertinoIcons.sparkles),
                _buildFilterButton(CommentFilterLevel.legend, '伝説', CupertinoIcons.flame),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSectionTitle('ミニマップ'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ページ ${widget.pageCount == 0 ? 0 : widget.currentPage + 1} / ${widget.pageCount}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          onPressed: widget.hasPrev ? widget.onPrevPage : null,
                          child: const Text('前へ', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          onPressed: widget.hasNext ? widget.onNextPage : null,
                          child: const Text('次へ', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildSectionTitle('検索結果'),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      _searchCtrl.text.isEmpty ? '検索キーワードを入力してください' : '見つかりませんでした',
                      style: const TextStyle(color: CupertinoColors.systemGrey),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final c = filtered[i];
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          title: Text(
                            '${c.id}. ${c.body.replaceAll('\n', ' ')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: const Icon(CupertinoIcons.location, size: 16),
                          onTap: () => widget.onJumpToComment(c.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

// ★★★ 返信一覧を表示するシート ★★★
class ReplyListSheet extends StatelessWidget {
  final List<Comment> replies;
  final Function(int, Offset?) onAnchorTap;
  final Function(String) onImageTap;
  final SettingsService settings;
  // ★ 追加: 再帰呼び出し用のコールバック
  final Function(List<int>)? onRepliesTap;
  final Function(int no)? onGoToComment;

  const ReplyListSheet({
    super.key,
    required this.replies,
    required this.onAnchorTap,
    required this.onImageTap,
    required this.settings,
    this.onRepliesTap, // ★ 追加
    this.onGoToComment,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: settings.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${replies.length}件の返信', style: const TextStyle(fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey),
                    ),
                  ],
                ),
              ),
              // リスト
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: replies.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final c = replies[index];
                      return CommentTile(
                        comment: c,
                        userStatus: CommentUserStatus.none,
                        onAnchorTap: (no, pos) => onAnchorTap(no, pos),
                        onImageTap: onImageTap,
                        checkAnchorAvailability: (no) => true,
                        fontSize: settings.fontSize,
                        onRepliesTap: onRepliesTap,
                        onTap: onGoToComment != null ? () {
                          Navigator.pop(context);
                          onGoToComment!(c.id);
                        } : null,
                      );
                  },
                ),
              ),
            ],
          ),
          
        );
      },
    );
  }
}
