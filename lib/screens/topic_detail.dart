// --- UI専用: TopicDetailScreen ---
// ロジックは controller, measurer, widgets/measure_size へ分離
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import '../widgets/measure_size.dart';
import '../utils/variable_list_measurer.dart';
import '../controllers/topic_detail_controller.dart';
import 'comment_post_webview.dart';
import 'image_viewer_page.dart';
import 'package:flutter/rendering.dart';

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
  Set<int> _clippedCommentNos = {};
  final VariableListMeasurer _meas = VariableListMeasurer();
  bool _restoring = false;

  // ================== State フィールド追加 ==================
  late final ScrollController _sc;
  final _centerKey = GlobalKey();       // B側（アンカー含む側）の key
  GlobalKey? _anchorItemKey;            // アンカー行に付ける key
  bool _restored = false;               // 局所オフセットの微調整を一度だけ実施
  int _currentAnchorIndex = 0;          // center 使用時、A側の件数（保存時の補正に使う）

  DateTime? _lastSaveAt;                // スクロール保存のスロットル
  final _saveInterval = const Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _sc = ScrollController()..addListener(_onScroll);
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

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});                 // comments 更新で再描画
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _sc.removeListener(_onScroll);
    _sc.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ...（以降、既存の全メソッド・ウィジェットビルダー・build等をクラス内にそのまま残す）...


  void _showAnchorPreview(int no) {
    final comment = _vm.getCommentByNo(no);
    if (comment.isEmpty) {
      PlatformHelper.showSnackBar(context, 'コメントが見つかりません');
      return;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final anchors = (comment['anchors'] as List?)?.cast<int>() ?? const <int>[];
        final revAnchors = (comment['reverse_anchors'] as List?)?.cast<int>() ?? const <int>[];

        return SafeArea(
          top: false, // 下からのシートなので上だけ無効に
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
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
                    decoration: const BoxDecoration(
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

                  // 本文スクロール領域
                  Expanded(
                    child: CupertinoScrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (anchors.isNotEmpty) _buildAnchorText(anchors),
                            if (revAnchors.isNotEmpty) _buildReverseAnchorText(revAnchors),

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
                                      return const SizedBox(
                                        height: 200,
                                        child: Center(child: CupertinoActivityIndicator()),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => const SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: Icon(CupertinoIcons.photo, size: 40, color: CupertinoColors.systemGrey),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // プラス/マイナス/クリップ
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('＋${comment['plus'] ?? 0}',
                                        style: const TextStyle(color: Color(0xFFED6D74))),
                                    const SizedBox(width: 16),
                                    Text('−${comment['minus'] ?? 0}',
                                        style: const TextStyle(color: CupertinoColors.secondaryLabel)),
                                  ],
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () async {
                                    await _vm.toggleClip(comment);
                                    if (context.mounted) Navigator.pop(context);
                                  },
                                  child: Icon(
                                    _vm.clippedNos.contains(comment['no'])
                                        ? CupertinoIcons.heart_fill
                                        : CupertinoIcons.heart,
                                    color: _vm.clippedNos.contains(comment['no'])
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
  // ================== build 差し替え（リスト部） ==================
  @override
  Widget build(BuildContext context) {
    final comments = _vm.comments;
    final savedNo = _vm.savedCommentNo;
    final hasAnchor = savedNo > 0 && comments.isNotEmpty;

    // no -> index は Controller 側の逆引きを優先、なければ線形検索
    int findIndexByNo(int no) {
      final m = _vm.indexByNo;
      final i = m[no];
      if (i != null) return i;
      return comments.indexWhere((c) => (c['no'] as int?) == no);
    }

    final anchorIndex = hasAnchor ? findIndexByNo(savedNo) : -1;
    final usingCenter = hasAnchor && anchorIndex >= 0 && anchorIndex < comments.length;

    // 保存時の補正用に保持（center を使っている間は _sc.offset が「B側先頭から」の座標になるため）
    _currentAnchorIndex = usingCenter ? anchorIndex : 0;

    // アンカー行用の key を用意（保存 no が変わったら作り直し）
      if (usingCenter && _anchorItemKey == null) {
          _anchorItemKey = GlobalKey();
          _restored = false; // 新しいアンカーになったらもう一度だけ微調整
      }

    // Sliver 構成：A（アンカーより前） + B（アンカーを含む側＝center）
    final slivers = <Widget>[
      if (usingCenter)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _buildRow(comments[i]),
            childCount: anchorIndex,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
          ),
        ),

      SliverList(
        key: usingCenter ? _centerKey : null,
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final index = usingCenter ? (anchorIndex + i) : i;
            final isAnchor = usingCenter && index == anchorIndex;
            return KeyedSubtree(
              key: isAnchor ? _anchorItemKey : ValueKey(comments[index]['no']),
              child: _buildRow(comments[index]),
            );
          },
          childCount: usingCenter ? (comments.length - anchorIndex) : comments.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
        ),
      ),
    ];

    // 初回の 1 フレーム後に “アンカーの中での局所オフセット” だけ微調整
    if (usingCenter && !_restored) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _adjustAnchorLocalOffset());
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
            : CustomScrollView(
                controller: _sc,
                center: usingCenter ? _centerKey : null, // ← これがポイント
                slivers: slivers,
              ),
      ),
    );
  }

  // コメント1行のUI（既存の実装に置き換え）
  Widget _buildRow(Map<String, dynamic> c) {
    // 例: return CommentTile(comment: c);
    return _buildCommentItem(context, c, _vm.indexByNo[c['no']] ?? 0);
  }

  // ================== 局所オフセットの微調整 ==================
  void _adjustAnchorLocalOffset() {
    if (!mounted || !_sc.hasClients) return;
    final box = _anchorItemKey?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final frac = _vm.savedLocalFraction.clamp(0.0, 1.0);
    final dy = box.size.height * frac;

    // center にしたことで “アンカー行が先頭に来ている” 前提で、行内の位置だけをずらす
    _sc.jumpTo(_sc.offset + dy);
    _restored = true;
  }

  // ================== スクロール保存（index と 比率） ==================
  void _onScroll() {
    if (!_sc.hasClients) return;

    // スパム防止（0.5秒に1回保存）
    final now = DateTime.now();
    if (_lastSaveAt != null && now.difference(_lastSaveAt!) < _saveInterval) return;
    _lastSaveAt = now;

    // center を使っている間は、_sc.offset は「B側先頭からの距離」。
    // 「全体リストの先頭からの距離」に直すため、A側のオフセットを足す。
  final baseOffset = _meas.indexToOffset(_currentAnchorIndex);
  final globalOffset = _sc.offset + baseOffset;

  final topIndex = _meas.offsetToIndex(globalOffset, _vm.comments.length);
  final rowTop  = _meas.indexToOffset(topIndex);
  final h       = _meas.getItemHeight(topIndex) ?? _meas.fallbackHeight;
  final frac    = h <= 0 ? 0.0 : ((globalOffset - rowTop) / h).clamp(0.0, 1.0);

  _vm.saveScrollByIndexAndFraction(topIndex, frac);
  }

  int _restoreTries = 0;

  double? _exactOffsetFor(GlobalKey key, {double alignment = 0}) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro == null) return null;
    final vp = RenderAbstractViewport.of(ro);
    if (vp == null) return null;
    return vp.getOffsetToReveal(ro, alignment).offset;
  }

  void _restoreScrollAfterBuild() {
    final savedNo = _vm.savedCommentNo;
    if (savedNo <= 0 || _vm.comments.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_sc.hasClients) return;

      _restoring = true;
      try {
        // 1) 粗いジャンプ（目標の少し手前まで）→ターゲットをビルドさせる
        final idx = _vm.comments.indexWhere((c) => c['no'] == savedNo);
        final warmIdx = (idx > 8) ? idx - 8 : 0;
        _meas.ensureCapacity(_vm.comments.length);
        final rough = _meas.indexToOffset(warmIdx).clamp(0.0, _sc.position.maxScrollExtent);
        _sc.jumpTo(rough);

        // 2) ターゲットがツリーに乗るまで数フレーム待つ
        final key = _meas.keyForNo(savedNo);
        for (int i = 0; i < 12; i++) { // ≒ 最大 ~200ms
          if (key.currentContext != null) break;
          await Future.delayed(const Duration(milliseconds: 16));
        }

        // 3) 正確なオフセットを算出して一発で合わせる（上揃え）
        final exact = _exactOffsetFor(key, alignment: 0.0);
        if (exact != null && _sc.hasClients) {
          final clamped = exact.clamp(0.0, _sc.position.maxScrollExtent);
          _sc.jumpTo(clamped);
        }

        // （任意）可視確認のため 1 回だけ ensureVisible を投げたい場合はここで
        // if (key.currentContext != null) {
        //   await Scrollable.ensureVisible(key.currentContext!, alignment: 0.0, duration: Duration.zero);
        // }
      } finally {
        _restoring = false;
      }
    });
  }

  Widget _buildRefreshableList(BuildContext context) {
    final items = _vm.comments;
    _meas.ensureCapacity(items.length);

    return CupertinoScrollbar(
      controller: _sc,
      child: CustomScrollView(
        controller: _sc,
        primary: false,
        cacheExtent: 1200,
        slivers: [
          if (widget.enableRefresh)
            CupertinoSliverRefreshControl(onRefresh: () async { await _vm.fetchDelta(); }),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i == items.length) {
                  return _vm.loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CupertinoActivityIndicator(),
                        )
                      : const SizedBox.shrink();
                }
                final c = items[i];
                final no = c['no'] as int? ?? -1;
                return MeasureSize(
                  onChange: (sz) => _meas.onItemSize(i, sz.height, sc: _sc),
                  child: Container(
                    key: _meas.keyForNo(no),
                    child: _buildCommentItem(context, c, i),
                  ),
                );
              },
              childCount: items.length + (_vm.loadingMore ? 1 : 0),
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
