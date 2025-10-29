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

/// トピック詳細画面 (UI専用)
/// ロジックは TopicDetailController, VariableListMeasurer, MeasureSize へ分離
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
  late final TopicDetailController _vm;
  Set<int> _clippedCommentNos = {};

  final _sc = ScrollController();
  final _meas = VariableListMeasurer(fallbackHeight: 250.0);
  Timer? _autoThrottle;
  bool _restoring = false;

  // ===== アンカープレビュー =====
  void _showAnchorPreview(int no) {
    debugPrint('👀 アンカープレビュー: No.$no');
    final comment = _vm.getCommentByNo(no);
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
                              await _vm.toggleClip(comment);
                              if (mounted) {
                                Navigator.pop(context);
                              }
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
            : NotificationListener<ScrollEndNotification>(
                onNotification: (_) { _saveScrollPosition(); return false; },
                child: _buildRefreshableList(context),
              ),
      ),
    );
  }

  int _restoreTries = 0;

  void _restoreScrollAfterBuild() {
    final savedNo = _vm.savedCommentNo;
    final noList = _vm.comments.map((c) => c['no']).toList();
    final head = noList.take(10).toList();
    final tail = noList.length > 20 ? noList.skip(noList.length - 10).toList() : [];
    debugPrint('🟦 savedNo=$savedNo, コメントNoリスト: head=$head ... tail=$tail (total=${noList.length})');

    if (!mounted || savedNo <= 0 || _vm.comments.isEmpty) {
      _restoring = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) { _restoring = false; return; }
      if (!_sc.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _restoreScrollAfterBuild();
        });
        return;
      }

      // 1) savedNo or 直前no を idx に解決
      int idx = _vm.comments.indexWhere((c) => c['no'] == savedNo);
      if (idx < 0) {
        int? nearestNo; int nearestIdx = -1;
        for (int i = 0; i < _vm.comments.length; i++) {
          final n = _vm.comments[i]['no'];
          if (n is int && n <= savedNo) {
            if (nearestNo == null || n > nearestNo) { nearestNo = n; nearestIdx = i; }
          }
        }
        idx = nearestIdx >= 0 ? nearestIdx : 0;
      }

      _meas.ensureCapacity(_vm.comments.length);
      _meas.markRestoreTargetIndex(idx);

      // 2) まず推定でジャンプ（fallback=250 でかなり末尾寄りになる）
      double est = _meas.indexToOffset(idx);
      _sc.jumpTo(est.clamp(0.0, _sc.position.maxScrollExtent));
      final targetNo = _vm.comments[idx]['no'];
      debugPrint('🟦 推定ジャンプ: savedNo=$savedNo, idx=$idx, noAtIdx=$targetNo, offset=${_sc.offset}, maxScrollExtent=${_sc.position.maxScrollExtent}, heightAtIdx=${_meas.getItemHeight(idx)}');

      // 3) ハンター式補正: 画面高ずつ前進して対象セルを build させる
      void hunt(int tries) {
        if (!mounted) { _restoring = false; return; }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final viewH = MediaQuery.of(context).size.height;
          final max = _sc.position.maxScrollExtent;
          final measured = _meas.isMeasured(idx);

          // 末尾側なら一気に最下端へブースト（最後の30件は下スクロールで確実にbuild）
          if (!measured && idx >= _vm.comments.length - 30 && _sc.offset < max - 24) {
            _sc.jumpTo(max);
          }

          if (measured) {
            final off = _meas.indexToOffset(idx).clamp(0.0, _sc.position.maxScrollExtent);
            _sc.jumpTo(off);
            _meas.ensureVisibleOnce(targetNo);
            debugPrint('🟩 補正ジャンプ: savedNo=$savedNo, idx=$idx, noAtIdx=$targetNo, offset=$off, maxScrollExtent=${_sc.position.maxScrollExtent}, heightAtIdx=${_meas.getItemHeight(idx)}, measured=true');
            _restoring = false;
            return;
          }

          // これでも未計測なら、画面高の0.9倍ずつ前進して強制的に近傍をレイアウト
          if (tries < 12) {
            final next = (_sc.offset + viewH * 0.9).clamp(0.0, _sc.position.maxScrollExtent);
            _sc.jumpTo(next);
            hunt(tries + 1);
          } else {
            // どうしても捕まらない場合は最後に ensureVisible を試行して終了
            _meas.ensureVisibleOnce(targetNo);
            debugPrint('🟨 補正妥協: measured=false のまま ensureVisible を投げて終了');
            _restoring = false;
          }
        });
      }
      hunt(0);
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
            CupertinoSliverRefreshControl(onRefresh: () => _vm.fetchDelta()),
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

  void _saveScrollPosition() {
  if (_restoring || !_sc.hasClients || _vm.comments.isEmpty) return;
    final idx = _meas.offsetToIndex(_sc.offset, _vm.comments.length);
    _vm.saveScrollByIndex(idx);
  }

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
    )..addListener(() => setState(() {}));

    _vm.init().then((_) {
      if (!mounted) return;
      _restoring = true;
      _restoreScrollAfterBuild();
    });

    _sc.addListener(() {
      if (_restoring) return; // 復元中は一切通信させない
      final pos = _sc.position;
      if (pos.pixels >= pos.maxScrollExtent - 80) {
        // 明示アクションのみ通信したいなら何もしない
        // 必要なら手動読み込みボタンで fetchDelta を呼ぶ
      }
    });
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _autoThrottle?.cancel();
    _sc.dispose();
    _vm.dispose();
    super.dispose();
  }
}
