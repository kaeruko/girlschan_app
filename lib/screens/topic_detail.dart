// --- UI専用: TopicDetailScreen ---
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import '../controllers/topic_detail_controller.dart';
import '../utils/variable_list_measurer.dart';
import '../widgets/measure_size.dart';
import 'comment_post_webview.dart';
import 'image_viewer_page.dart';

class TopicDetailScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String posted_at;

  final bool enableRefresh;
  final bool testingBypassInit;
  final List<Map<String, dynamic>>? testingInitialComments;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.posted_at,
    this.enableRefresh = true,
    this.testingBypassInit = false,
    this.testingInitialComments,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  // ========== フィールド群 ==========
  late final TopicDetailController _vm;
  static const int _pageSize = 10;
  final PageController _pc = PageController();
  final Map<int, ScrollController> _pageScroll = {};             // page -> ScrollController
  final Map<int, VariableListMeasurer> _pageMeas = {};           // page -> measurer
  int _currentPage = 0;

  bool _restoring = false;          // 復元中は保存/ロードを止める
  bool _restoredOnce = false;       // 一度でも復元が成功したか
  bool _loadingMore = false;        // 末尾ページの追加ロード中
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
      testingBypassInit: widget.testingBypassInit,
      testingInitialComments: widget.testingInitialComments,
    )..addListener(_onVmChanged);

    _vm.init();
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
    // 初回データ到着後は復元を試みる
    if (!_restoredOnce && !_vm.loading) {
      _scheduleTryRestore();
    }
  }

  // ========== 2) 追加: ページングのヘルパー ==========
  int _pageCountFor(int total) => (total + _pageSize - 1) ~/ _pageSize;

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
    _vm.saveScrollByIndexAndFraction(globalIndex, frac);
  }

  // ========== 4) 追加: 復元（savedCommentNo をページにマップ） ==========
  void _scheduleTryRestore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreIfNeeded();
    });
  }

  Future<void> _tryRestoreIfNeeded() async {
    if (_restoredOnce || _vm.loading) return;

    final savedNo = _vm.savedCommentNo;
    if (savedNo <= 0) { 
      _restoredOnce = true;
      return; 
    }

    // まず、そのNoが入るまで差分取得（既存のユーティリティを活用）
    await _vm.ensureContainsNo(savedNo);
    if (!mounted) return;

    // index を特定してターゲットページへ
    final idx = _vm.indexByNo[savedNo];
    if (idx == null) {
      // まだ取れてない場合は次フレームでもう一度
      _scheduleTryRestore();
      return;
    }

    final targetPage = idx ~/ _pageSize;

    _restoring = true;
    if (_pc.hasClients) {
      _pc.jumpToPage(targetPage);
    }

    // 該当行がビルドされるのを待って ensureVisible → 行内フラクションで微調整
    for (int attempt = 0; attempt < 24; attempt++) {
  final ctx = _measForPage(targetPage).keyForNo(savedNo).currentContext;
      if (ctx != null) {
        // 行頭を上端に（アニメなしで正確に）
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
        if (h > 0 && frac > 0) {
          final sc = _scForPage(targetPage);
          if (sc.hasClients) {
            final max = sc.position.maxScrollExtent;
            sc.jumpTo((sc.offset + h * frac).clamp(0.0, max));
          }
        }

  _vm.clearScrollFractionOnly(); // フラクションは使い切り
        _restoring = false;
        _restoredOnce = true;

        // 復元直後の正しい位置で一度保存
        _saveFromPage(targetPage);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 16));
    }

    // うまく行かなければ次フレームで再挑戦できるように戻す
    _restoring = false;
    _scheduleTryRestore();
  }


  // ==== UI ====
  @override
  Widget build(BuildContext context) {
    final items = _vm.comments;
    final pageCount = _pageCountFor(items.length);

    // 自動復元は初回データ到着後にポストフレームで試行
    if (!_restoredOnce && !_vm.loading) {
      _scheduleTryRestore();
    }

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
              cacheExtent: 1200.0,
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
                        child: Container(
                          key: meas.keyForNo(no), // 行キー（ensureVisible用）
                          child: _buildCommentItem(ctx2, c, globalIndex),
                        ),
                      );
                    },
                    childCount: pageItems.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
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
            Text('コメント: ${widget.commentCount}', style: const TextStyle(fontSize: 11)),
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
        child: _vm.loading
            ? Center(child: PlatformHelper.buildLoadingIndicator())
            : Stack(
                children: [
                  pageView,

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
                if (!mounted) return;
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

  Widget _buildCommentItem(BuildContext context, dynamic c, int i) {
    final no = c['no'] ?? '-';
    final posted_at = c['posted_at'] ?? '';
    final body = c['body'] ?? '';
    final plus = c['plus'] ?? 0;
    final minus = c['minus'] ?? 0;
    final anchors = List<int>.from(c['anchors'] ?? []);
    final reverseAnchors = List<int>.from(c['reverse_anchors'] ?? []);
    final urls = (c['urls'] as List?) ?? [];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No.$no  $posted_at${c['isLocal'] == true ? ' （ローカル）' : ''}',
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
                  final success = await rateComment(widget.topicId, commentId, 1);
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
                  final success = await rateComment(widget.topicId, commentId, -1);
                  if (!mounted) return;
                  if (success) setState(() => c['minus'] = (c['minus'] ?? 0) + 1);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('−$minus', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  await _vm.toggleClip(Map<String, dynamic>.from(c));
                  if (!mounted) return;
                  setState(() {});
                },
                child: Icon(
                  _vm.clippedNos.contains(no) ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: _vm.clippedNos.contains(no)
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
    if (!mounted) return;
  }

  Widget _buildPlusMinusGraph(int plus, int minus) {
    final total = plus + minus;
    if (total == 0) return const SizedBox.shrink();
    return Row(
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
    );
  }
}
