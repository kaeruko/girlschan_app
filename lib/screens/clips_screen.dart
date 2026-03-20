import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // OverlayやIconsで使用
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/history_notifier.dart';
import '../services/settings_service.dart';
import '../screens/topic_detail.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart'; // トーストは重要な通知のみに使用
import '../app/app_tabs.dart';
import 'label_management_screen.dart';

class ClipsScreen extends StatefulWidget {
  final Function(int topicId, String title, int comments, String postedAt)? onTopicTap;
  final Function(int topicId, String title, int comments, String postedAt)? onTopicNewTabTap;

  const ClipsScreen({
    super.key,
    this.onTopicTap,
    this.onTopicNewTabTap,
  });

  @override
  State<ClipsScreen> createState() => ClipsScreenState();
}

class ClipsScreenState extends State<ClipsScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _clips = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _inFlight = false;
  bool _metaUpdating = false;

  // ★ UI更新用ステータス変数
  String _progressStatus = ''; // 画面上部の進捗バー用
  int? _updatingTopicId;       // 現在チェック中のID
  int? _updatingNo;            // 現在チェック中のレス番
  final Map<String, String> _updateDiffs = {}; // 差分メッセージ保持用 ("topicId-no": "+3")

  // ラベル関連
  List<Map<String, dynamic>> _labels = [];
  int _selectedLabelId = 0;

  // 設定サービス
  final _settings = SettingsService();

  // 日付解析用正規表現（コンパイル済）
  static final _dateRegex = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2}).*?(\d{1,2}):(\d{2})');

  void reloadFromOutside() {
    _loadClips();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
    clipsUpdateNotifier.addListener(_loadClips);
    _loadClips();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    clipsUpdateNotifier.removeListener(_loadClips);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadClips();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  // ★ アプリ内通知（オーバーレイ）を表示するメソッド
  void _showInAppNotification({
    required String title,
    required String message,
    required VoidCallback onTap,
  }) {
    if (!mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Dismissible(
                  key: UniqueKey(),
                  direction: DismissDirection.up,
                  onDismissed: (_) => overlayEntry.remove(),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const Icon(CupertinoIcons.reply_thick_solid, color: CupertinoColors.activeBlue, size: 32),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      overlayEntry.remove();
                      onTap();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) overlayEntry.remove();
    });
  }

  DateTime? parseGirlsChanPostedAt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.contains('前')) return DateTime.now();
    final m = _dateRegex.firstMatch(s);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    }
    return DateTime.now();
  }

  Future<void> _loadClips() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final clips = await getClippedComments();
      final labels = await getClipLabels();
      
      clips.sort((a, b) {
        final dateA = parseGirlsChanPostedAt(a['clipDate'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = parseGirlsChanPostedAt(b['clipDate'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      
      if (!mounted) return;
      setState(() {
        _clips = clips;
        _labels = labels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _clips = [];
      });
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _loadClips();
    if (mounted) setState(() => _refreshing = false);
    _startBackgroundThreadUpdate(targetLabelId: _selectedLabelId);
  }

  void _startBackgroundThreadUpdate({int? targetLabelId}) {
    if (_metaUpdating) return;

    _metaUpdating = true;
    clipsUpdatingNotifier.value = true;

    _backgroundUpdateThreads(targetLabelId: targetLabelId).whenComplete(() {
      _metaUpdating = false;
      clipsUpdatingNotifier.value = false;
    });
  }

Future<void> _backgroundUpdateThreads({int? targetLabelId}) async {
    final now = DateTime.now();
    
    // 更新対象の抽出
    final targets = _clips.where((c) {
      if (targetLabelId != null && (c['labelId'] ?? 0) != targetLabelId) return false;
      final postedAtStr = c['posted_at'] as String? ?? '';
      final postedAt = parseGirlsChanPostedAt(postedAtStr);
      if (postedAt != null && now.difference(postedAt).inDays > 31) return false;
      return true;
    }).toList();

    final total = targets.length;
    if (total == 0) return;

    if (mounted) {
      setState(() {
        _progressStatus = '更新チェックを開始します...';
        _updateDiffs.clear();
      });
    }

    for (int i = 0; i < total; i++) {
      if (!mounted) break;

      final clip = targets[i];
      final topicId = clip['topicId'] as int;
      final commentNo = clip['no'] as int;
      final topicTitle = clip['topicTitle'] as String? ?? '';
      final postedAtStr = clip['posted_at'] as String? ?? '';

      setState(() {
        _updatingTopicId = topicId;
        _updatingNo = commentNo;
        _progressStatus = 'チェック中: ${i + 1} / $total 件';
      });

      try {
        final index = _clips.indexWhere((c) => c['topicId'] == topicId && c['no'] == commentNo);
        if (index == -1) continue;

        final thread = await fetchCommentThread(topicId, commentNo);

        if (thread != null && thread['comments'] is List && (thread['comments'] as List).isNotEmpty) {
          final commentsList = thread['comments'] as List<dynamic>;
          final first = commentsList.first as Map<String, dynamic>;
          
          final newPlus = first['plus'] as int? ?? 0;
          final newMinus = first['minus'] as int? ?? 0;
          final oldPlus = _clips[index]['plus'] as int? ?? 0;
          final oldMinus = _clips[index]['minus'] as int? ?? 0;

          final newReverseAnchorsList = (first['reverse_anchors'] as List?) ?? [];
          final oldReverseAnchorsList = (_clips[index]['reverse_anchors'] as List?) ?? [];
          
          // 差分チェック (プラス・マイナス)
          final diffMessages = <String>[];
          if (newPlus > oldPlus) diffMessages.add('＋${newPlus - oldPlus}');
          if (newMinus > oldMinus) diffMessages.add('−${newMinus - oldMinus}');

          // ★ 返信チェック & プレビュー取得
          bool hasNewReply = false;
          String? replyPreview; // ポップアップ用（長め）
          String? badgePreview; // カードの赤帯用（短め）
          int? replyCommentNo;

          if (newReverseAnchorsList.length > oldReverseAnchorsList.length) {
            hasNewReply = true;
            final addedIds = newReverseAnchorsList.where((id) => !oldReverseAnchorsList.contains(id)).toList();
            
            if (addedIds.isNotEmpty) {
              final latestNewId = addedIds.last;
              replyCommentNo = latestNewId;
              final replyComment = commentsList.firstWhere((c) => c['no'] == latestNewId, orElse: () => null);
              
              if (replyComment != null) {
                String body = replyComment['body'] as String? ?? '';
                // アンカー(>>123)と改行を除去
                body = body.replaceFirst(RegExp(r'^>>\d+\s*'), '').replaceAll('\n', ' ');
                
                // ポップアップ用は30文字
                replyPreview = body.length > 30 ? '${body.substring(0, 30)}...' : body;
                
                // カードの赤帯用はスペースがないので10文字程度に詰める
                badgePreview = body.length > 12 ? '${body.substring(0, 12)}...' : body;
              }
            }
          }

          if (mounted) {
            setState(() {
              // データ更新
              _clips[index]['plus'] = newPlus;
              _clips[index]['minus'] = newMinus;
              _clips[index]['anchors'] = first['anchors'] ?? [];
              _clips[index]['reverse_anchors'] = newReverseAnchorsList;

              // ★ 差分保存（ここを変更しました）
              // 「返信あり」ではなく「返信: プレビュー」を表示
              if (diffMessages.isNotEmpty || hasNewReply) {
                final key = '$topicId-$commentNo';
                
                // 返信メッセージの作成
                String replyMsg = '';
                if (hasNewReply) {
                   if (badgePreview != null) {
                     replyMsg = '返信 >>$replyCommentNo「$badgePreview」';
                   } else {
                     replyMsg = replyCommentNo != null ? '返信 >>$replyCommentNo' : '新着返信あり';
                   }
                }

                final msg = [
                  if (replyMsg.isNotEmpty) replyMsg,
                  ...diffMessages
                ].join(', ');
                
                _updateDiffs[key] = msg;
              }
            });

            // ★ 返信があったらポップアップ通知（ここは変更なし）
            if (hasNewReply) {
              _showInAppNotification(
                title: '返信がつきました！',
                message: replyPreview != null ? '「$replyPreview」' : topicTitle,
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => TopicDetailScreen(
                        topicId: topicId,
                        title: topicTitle,
                        commentCount: 0,
                        postedAt: postedAtStr,
                        initialJumpTo: commentNo,
                        saveReadPosition: false,
                      ),
                    ),
                  );
                },
              );
            }
          }
          
          // 保存処理
          await updateClippedCommentStats(
            topicId: topicId,
            commentNo: commentNo,
            plus: newPlus,
            minus: newMinus,
            anchors: _clips[index]['anchors'],
            reverse_anchors: _clips[index]['reverse_anchors'],
          );
        }
      } catch (e) {
        debugPrint('Update failed: $e');
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    if (mounted) {
      setState(() {
        _updatingTopicId = null;
        _updatingNo = null;
        _progressStatus = '';
      });
    }
  }

  Future<void> _removeClip(Map<String, dynamic> clip) async {
    final topicId = clip['topicId'] as int;
    final no = clip['no'] as int;
    await removeClippedComment(topicId, no);
    if (!mounted) return;
    setState(() {
      _clips.removeWhere((c) => c['topicId'] == topicId && c['no'] == no);
    });
  }

  Future<void> _updateMemo(Map<String, dynamic> clip, String memo) async {
    final topicId = clip['topicId'] as int;
    final no = clip['no'] as int;
    await updateClippedCommentMemo(topicId, no, memo);
    if (!mounted) return;
    setState(() {
      final index = _clips.indexWhere((c) => c['topicId'] == topicId && c['no'] == no);
      if (index != -1) {
        _clips[index]['memo'] = memo;
      }
    });
  }

  void _showMemoDialog(Map<String, dynamic> clip) {
    final currentMemo = clip['memo'] as String? ?? '';
    final controller = TextEditingController(text: currentMemo);

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('メモ'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'メモを入力...',
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              _updateMemo(clip, controller.text);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showClipMenu(Map<String, dynamic> clip) {
    final hasMemo = (clip['memo'] as String? ?? '').isNotEmpty;

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showMemoDialog(clip);
            },
            child: Text(hasMemo ? 'メモを編集' : 'メモを追加'),
          ),
          if (hasMemo)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _updateMemo(clip, '');
              },
              child: const Text('メモを削除'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(ClipboardData(text: clip['body'] as String));
            },
            child: const Text('コピー'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _removeClip(clip);
            },
            child: const Text('クリップを削除'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClips = _clips.where((c) => (c['labelId'] ?? 0) == _selectedLabelId).toList();

    return CupertinoPageScaffold(
      backgroundColor: _settings.backgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('クリップ'),
        transitionBetweenRoutes: false, // エラー回避のため明示的に設定
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.bars),
          onPressed: () async {
            await showCupertinoModalPopup(
              context: context,
              builder: (context) => CupertinoActionSheet(
                actions: [
                  CupertinoActionSheetAction(
                    onPressed: () async {
                      Navigator.pop(context);
                      await Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const LabelManagementScreen()));
                      _loadClips();
                    },
                    child: const Text('ラベル管理'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(context);
                      _startBackgroundThreadUpdate(targetLabelId: null);
                    },
                    child: const Text('全ラベルを更新'),
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: AppSpinner(size: 32, showLabel: true))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _refresh),

                  // ラベルバー
                  SliverToBoxAdapter(
                    child: Container(
                      height: 50,
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey5)),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: _labels.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final label = _labels[index];
                          final id = label['id'] as int;
                          final isSelected = id == _selectedLabelId;
                          final count = _clips.where((c) => (c['labelId'] ?? 0) == id).length;
                          // ... ラベル表示の残りは元のコードと同じ ...
                          return GestureDetector(
                            onTap: () => setState(() => _selectedLabelId = id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? CupertinoColors.activeBlue : CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Text(label['name'] == '' ? '未分類' : label['name'],
                                      style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                  if (count > 0) ...[
                                    const SizedBox(width: 4),
                                    Text('($count)',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: isSelected ? Colors.white70 : Colors.grey)),
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ★ 進捗バー
                  if (_progressStatus.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CupertinoActivityIndicator(radius: 8),
                            const SizedBox(width: 8),
                            Text(
                              _progressStatus,
                              style: const TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.systemBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (filteredClips.isEmpty)
                     // ... 空表示のロジック ...
                     const SliverFillRemaining(
                        child: Center(child: Text('クリップはありません', style: TextStyle(color: Colors.grey))),
                     )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildClipItem(filteredClips[index]),
                          childCount: filteredClips.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildClipItem(Map<String, dynamic> clip) {
    // データ展開
    final topicTitle = clip['topicTitle'] as String;
    final commentBody = clip['body'] as String;
    final commentNo = clip['no'] as int;
    final posted_at = clip['posted_at'] as String;
    final plus = clip['plus'] as int;
    final minus = clip['minus'] as int;
    final topicId = clip['topicId'] as int;
    final name = clip['name'] as String? ?? '匿名';
    final memo = clip['memo'] as String? ?? '';
    final imageUrl = clip['image_url'] as String?;
    final rawUrls = clip['urls'] as List<dynamic>? ?? [];

    // ★ 更新中かどうかの判定（IDで厳密に）
    final isUpdating = (_updatingTopicId == topicId && _updatingNo == commentNo);
    
    // ★ 差分メッセージの取得
    final diffKey = '$topicId-$commentNo';
    final diffMessage = _updateDiffs[diffKey];

    return GestureDetector(
      onLongPress: () => _showClipMenu(clip),
      onTap: () {
        // Cmd+クリック (macOS) / Ctrl+クリック (Windows) → 新規タブで開く
        if (widget.onTopicNewTabTap != null) {
          final isMeta = HardwareKeyboard.instance.isMetaPressed;
          final isCtrl = HardwareKeyboard.instance.isControlPressed;
          if (isMeta || isCtrl) {
            widget.onTopicNewTabTap!(topicId, topicTitle, 0, posted_at);
            return;
          }
        }
        if (widget.onTopicTap != null) {
          widget.onTopicTap!(topicId, topicTitle, 0, posted_at);
          return;
        }
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => TopicDetailScreen(
              topicId: topicId,
              title: topicTitle,
              commentCount: 0,
              postedAt: posted_at,
              initialJumpTo: commentNo,
              saveReadPosition: false,
            ),
          ),
        ).then((_) {
          _loadClips();
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          border: Border.all(color: CupertinoColors.separator, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topicTitle,
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // ★ 更新中くるくる
                if (isUpdating) ...[
                  const SizedBox(width: 8),
                  const CupertinoActivityIndicator(radius: 7),
                ]
              ],
            ),
            
            // ★ 差分表示エリア（赤い帯）
            if (diffMessage != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CupertinoColors.systemRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.bell_fill, size: 12, color: CupertinoColors.systemRed),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        diffMessage,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.systemRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),
            Text(
              commentBody,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: _settings.fontSize),
            ),
            
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    height: 150,
                    child: Center(child: CupertinoActivityIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ],
            
            // ... URLプレビューとメモ（変更なし）...
            if (rawUrls.isNotEmpty) ...[
               const SizedBox(height: 8),
               // (簡易実装)
               ...rawUrls.map((u) => Text(u['url'] ?? '', style: const TextStyle(color: Colors.blue, fontSize: 12))),
            ],

            if (memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemYellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(memo, style: const TextStyle(fontSize: 13)),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'No.$commentNo • $name • $posted_at • ＋$plus −$minus',
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // アンカー数など...
                if ((clip['anchors'] as List?)?.isNotEmpty == true || (clip['reverse_anchors'] as List?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${((clip['anchors'] as List?)?.length ?? 0) > 0 ? "↔${(clip['anchors'] as List).length}" : ""}${((clip['reverse_anchors'] as List?)?.length ?? 0) > 0 ? " ⟸${(clip['reverse_anchors'] as List).length}" : ""}',
                        style: const TextStyle(fontSize: 12, color: CupertinoColors.systemBlue),
                      ),
                    ),
                CupertinoButton(
                  padding: const EdgeInsets.all(4),
                  minSize: 26,
                  onPressed: () => _removeClip(clip),
                  child: const Icon(CupertinoIcons.xmark, size: 18, color: CupertinoColors.secondaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}