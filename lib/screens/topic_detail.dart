// --- UI専用: TopicDetailScreen ---
// ロジックは controller, measurer, widgets/measure_size へ分離
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import '../controllers/topic_detail_controller.dart';
import '../scroll/anchored_scroll_coordinator.dart';
import '../utils/variable_list_measurer.dart';
import '../widgets/measure_size.dart';
import 'comment_post_webview.dart';
import 'image_viewer_page.dart';

class TopicDetailScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;
  final String posted_at;

  // ★ 追加: テスト用バイパス
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
  late final TopicDetailController _vm;

  // 復元フラグ
  bool _centerConsumed = false;

  // ① 先に ScrollController
  final _sc = ScrollController();

  // ② 1回だけ Coordinator を作る（_sc を渡す）
  late final AnchoredScrollCoordinator _scroll =
      AnchoredScrollCoordinator(controller: _sc);

  final VariableListMeasurer _meas = VariableListMeasurer();

  bool _loadingMore = false;
  static const double _loadMoreThreshold = 300;

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

    // ★ 1本のコントローラに全部ぶら下げる
    _sc.addListener(_onScrollSave);
    _sc.addListener(_onScrollBottomLoad);
    _vm.init();
  }

  void _onScrollSave() {
    // ★ 復元が終わるまで保存しない（上書き防止）
    if (!_centerConsumed) return;
    if (!_sc.hasClients) return;
    _scroll.onScrollSave(
      measurer: _meas,
      totalCount: _vm.comments.length,
      save: (index, frac) {
        final f = frac.isFinite ? frac.clamp(0.0, 1.0) : 0.0;
        _vm.saveScrollByIndexAndFraction(index, f);
      },
    );
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});                 // comments 更新で再描画
  }

  @override
  void dispose() {
    _sc.removeListener(_onScrollSave);
    _sc.removeListener(_onScrollBottomLoad);
    _sc.dispose();
    _scroll.dispose();       // 外部注入なので中では dispose されない（安全）
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  void _onScrollBottomLoad() {
    if (_loadingMore || !_sc.hasClients) return;
    final pos = _sc.position;
    if (!pos.hasPixels) return;
    if (pos.extentAfter <= _loadMoreThreshold) {
      final keepPinned = (pos.pixels >= pos.maxScrollExtent - 4);
      _fetchMoreDelta(keepPinned: keepPinned);
    }
  }

  Future<void> _fetchMoreDelta({bool keepPinned = false}) async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      final added = await _vm.fetchDelta();
      if (!mounted) return;
      if (keepPinned && (added > 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_sc.hasClients) {
            _sc.jumpTo(_sc.position.maxScrollExtent);
          }
        });
      }
      setState(() {});
    } finally {
      _loadingMore = false;
    }
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

  // =========================================
  // UI
  // =========================================
  @override
  Widget build(BuildContext context) {
    final items = _vm.comments;

    // 復元したいときだけ center 方式にする（1フレーム限定）
    final wantCenter = (_vm.savedCommentNo > 0) && !_centerConsumed;
    final savedNo    = wantCenter ? _vm.savedCommentNo : 0;

    // ① 先に willUseCenter を自前で判定（bundle を作る前）
    final idxMap = _vm.indexByNo;
    final anchorIndex = (savedNo > 0)
        ? (idxMap[savedNo] ?? items.indexWhere((e) => (e['no'] as int?) == savedNo))
        : -1;
    final willUseCenter =
        savedNo > 0 && anchorIndex >= 0 && anchorIndex < items.length;

    // ② willUseCenter を itemBuilder 内で使う（bundle は参照しない）
    final bundle = _scroll.buildAnchoredSlivers(
      items: items,
      savedNo: savedNo,
      indexByNo: (no) => idxMap[no] ?? -1,
      itemBuilder: (ctx, i) {
        _meas.ensureCapacity(items.length);
        final c  = items[i];
        final no = c['no'] as int? ?? -1;

        // ← 復元フレームは自動補正を殺す
        final suppressAdjust = willUseCenter && !_centerConsumed;

        return MeasureSize(
          onChange: (sz) => _meas.onItemSize(
            i,
            sz.height,
            sc: suppressAdjust ? null : _sc, // ★ここがポイント
          ),
          child: Container(
            key: _meas.keyForNo(no),
            child: _buildCommentItem(context, c, i),
          ),
        );
      },
    );


    final match = bundle.slivers.where((w) => w.key == bundle.centerKey).length;
    debugPrint('[center-check] using=${bundle.usingCenter} match=$match'); // ← match は必ず 1

    if (wantCenter && bundle.usingCenter) {
      _scroll.maybeScheduleLocalAdjust(
        usingCenter: true,
        savedFraction: _vm.savedLocalFraction,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_sc.hasClients) {
          setState(() {
            _centerConsumed = true;      // ← centerモード終了（通常リストへ）
            // これで _onScrollSave のガードが外れる
          });
          _vm.clearScrollFractionOnly(); // ← fractionだけ消す（一覧の履歴表示は残す）
        }
      });
    }


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
            : CupertinoScrollbar(
                controller: _sc,
                child: CustomScrollView(
                  controller: _sc,
                  center: bundle.usingCenter ? bundle.centerKey : null, // ← これが超重要
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [...bundle.slivers],
                ),
              ),
      ),
    );
  }
  // ================== 局所オフセットの微調整 ==================

  Widget _buildCommentItem(BuildContext context, dynamic c, int i) {
    final no = c['no'] ?? '-';
    final posted_at = c['posted_at'] ?? '';
    final body = c['body'] ?? '';
    final plus = c['plus'] ?? 0;
    final minus = c['minus'] ?? 0;
    final anchors = List<int>.from(c['anchors'] ?? []);
    final reverseAnchors = List<int>.from(c['reverse_anchors'] ?? []);
    final urls = (c['urls'] as List?) ?? [];
    // クリップ状態もcontroller経由で参照できるようにする（今後）

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
                  if (!mounted) return;
                  if (success) {
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
                  if (!mounted) return;
                  if (success) {
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
                  await _vm.toggleClip(c);
                  if (!mounted) return;
                  setState(() {});
                },
                child: Icon(
                  _vm.clippedNos.contains(no)
                      ? CupertinoIcons.heart_fill
                      : CupertinoIcons.heart,
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
    if (!mounted) return;
  }

  /// プラス・マイナスを表示する横長の棒グラフを作成
  Widget _buildPlusMinusGraph(int plus, int minus) {
    final total = plus + minus;
    if (total == 0) return const SizedBox.shrink();
    return Row(
      children: [
        // プラスの棒（ピンク）
        if (plus > 0)
          Expanded(
            flex: plus,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFED6D74),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                plus.toString(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.white),
              ),
            ),
          ),
        // マイナスの棒（灰色）
        if (minus > 0)
          Expanded(
            flex: minus,
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey3,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                minus.toString(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CupertinoColors.white),
              ),
            ),
          ),
      ],
    );
  }

  }
