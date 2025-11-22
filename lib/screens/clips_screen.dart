import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../screens/topic_detail.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';
import '../app/app_tabs.dart';
import 'label_management_screen.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});
  @override
  State<ClipsScreen> createState() => ClipsScreenState();
}

class ClipsScreenState extends State<ClipsScreen>
with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _clips = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _inFlight = false;  // ★ 重複ロード防止
  bool _metaUpdating = false;  // ★ バックグラウンド更新中かどうか
  
  // ★ ラベル関連
  List<Map<String, dynamic>> _labels = [];
  int _selectedLabelId = 0;

  /// ★ app_tab 側から叩くための公開メソッド
  void reloadFromOutside() {
    _loadClips();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadClips();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadClips();
  }

  Future<void> _loadClips() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final clips = await getClippedComments();
      final labels = await getClipLabels();
      
      clips.sort((a, b) {
        DateTime parseDate(String s) {
          try {
            return DateTime.parse(s);
          } catch (_) {
            return DateTime.fromMillisecondsSinceEpoch(0);
          }
        }
        return parseDate(b['clipDate'] as String)
            .compareTo(parseDate(a['clipDate'] as String));
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
    
    // バックグラウンド更新を開始（現在のラベルのみ）
    _startBackgroundThreadUpdate(targetLabelId: _selectedLabelId);
  }

  void _startBackgroundThreadUpdate({int? targetLabelId}) {
    if (_metaUpdating) {

      return;
    }

    _metaUpdating = true;
    clipsUpdatingNotifier.value = true;

    _backgroundUpdateThreads(targetLabelId: targetLabelId).whenComplete(() {
      _metaUpdating = false;
      clipsUpdatingNotifier.value = false;

    });
  }

  DateTime? parseGirlsChanPostedAt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.contains('前')) return DateTime.now();
    final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2}).*?(\d{1,2}):(\d{2})').firstMatch(s);
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

  // Fetch comment thread for each clip to refresh plus/minus and anchor counts
  Future<void> _backgroundUpdateThreads({int? targetLabelId}) async {
    
    final now = DateTime.now();
    bool hasUpdates = false;

    for (int i = 0; i < _clips.length; i++) {
      if (!mounted) break;
      
      final clip = _clips[i];
      
      // フィルタリング: targetLabelId が指定されている場合はそのラベルのみ
      if (targetLabelId != null && (clip['labelId'] ?? 0) != targetLabelId) {
        continue;
      }

      final topicId = clip['topicId'] as int;
      final commentNo = clip['no'] as int;
      final commentBody = clip['body'] as String? ?? '';
      final bodyPreview = commentBody.length > 30 ? '${commentBody.substring(0, 30)}...' : commentBody;
      
      // ★ dat落ちチェック
      final postedAtStr = clip['posted_at'] as String? ?? '';
      final postedAt = parseGirlsChanPostedAt(postedAtStr);
      if (postedAt != null) {
        final diffDays = now.difference(postedAt).inDays;
        if (diffDays > 31) {
    
          continue;
        }
      }

      // ★ チェック中トースト
      if (mounted) {
        AppToast.show(context, '「$bodyPreview」をチェック中...');
      }

      try {
  
        final thread = await fetchCommentThread(topicId, commentNo);

        if (thread != null && thread['comments'] is List && (thread['comments'] as List).isNotEmpty) {
          final first = (thread['comments'] as List).first as Map<String, dynamic>;
          final newPlus = first['plus'] as int? ?? clip['plus'];
          final newMinus = first['minus'] as int? ?? clip['minus'];
          final newAnchors = (first['anchors'] as List?)?.length ?? 0;
          final newReverseAnchors = (first['reverse_anchors'] as List?)?.length ?? 0;
          
          final oldPlus = clip['plus'] as int? ?? 0;
          final oldMinus = clip['minus'] as int? ?? 0;
          final oldAnchors = (clip['anchors'] as List?)?.length ?? 0;
          final oldReverseAnchors = (clip['reverse_anchors'] as List?)?.length ?? 0;

          // ★ _clips を直接更新
          _clips[i]['plus'] = newPlus;
          _clips[i]['minus'] = newMinus;
          _clips[i]['anchors'] = first['anchors'] ?? [];
          _clips[i]['reverse_anchors'] = first['reverse_anchors'] ?? [];
          hasUpdates = true;

          // ★ SharedPreferences にも保存
          await updateClippedCommentStats(
            topicId: topicId,
            commentNo: commentNo,
            plus: newPlus,
            minus: newMinus,
            anchors: _clips[i]['anchors'],
            reverse_anchors: _clips[i]['reverse_anchors'],
          );

          // ★ TopicDetailScreen のキャッシュも更新
          try {
            final cacheKey = 'comments_$topicId';
            final cachedComments = await CacheService.loadList(cacheKey);
            if (cachedComments.isNotEmpty) {
              bool cacheUpdated = false;
              for (int j = 0; j < cachedComments.length; j++) {
                final cached = cachedComments[j] as Map<String, dynamic>;
                if (cached['no'] == commentNo) {
                  cached['plus'] = newPlus;
                  cached['minus'] = newMinus;
                  cached['anchors'] = _clips[i]['anchors'];
                  cached['reverse_anchors'] = _clips[i]['reverse_anchors'];
                  cachedComments[j] = cached;
                  cacheUpdated = true;
                  break;
                }
              }
              if (cacheUpdated) {
                await CacheService.saveList(cacheKey, cachedComments);
          
              }
            }
          } catch (e) {
      
          }

          // ★ 変化を検出してトースト
          final changes = <String>[];
          if (newPlus > oldPlus) changes.add('プラスがつきました (+${newPlus - oldPlus})');
          if (newMinus > oldMinus) changes.add('マイナスがつきました (+${newMinus - oldMinus})');
          if (newAnchors > oldAnchors) changes.add('アンカーがつきました (+${newAnchors - oldAnchors})');
          if (newReverseAnchors > oldReverseAnchors) changes.add('コメントがつきました (+${newReverseAnchors - oldReverseAnchors})');
          
          if (changes.isNotEmpty) {
            if (mounted) {
              AppToast.show(
                context,
                '「$bodyPreview」に${changes.join('、')}',
              );
            }
          } else {
            if (mounted) {
              AppToast.show(context, '「$bodyPreview」は変更なし');
            }
          }
        }
      } catch (e) {
  
      }

      // ★ サーバー負荷を抑えるためのウェイト
      await Future.delayed(const Duration(seconds: 3));
    }

    if (mounted && hasUpdates) setState(() {});
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
    // ★ 1. 描画前にリストを確定させる（高速化のキモ）
    final filteredClips = _clips
        .where((c) => (c['labelId'] ?? 0) == _selectedLabelId)
        .toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('クリップ'),
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
                      await Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const LabelManagementScreen()),
                      );
                      _loadClips(); // 戻ってきたらリロード（ラベル変更反映）
                    },
                    child: const Text('ラベル管理'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(context);
                      _startBackgroundThreadUpdate(targetLabelId: null); // 全ラベル更新
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
            ? const Center(child: AppSpinner(size: 20))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _refresh),

                  // ★ ラベルバー
                  SliverToBoxAdapter(
                    child: Container(
                      height: 50,
                      decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: CupertinoColors.systemGrey5)),
                      ),
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: _labels.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final label = _labels[index];
                          final id = label['id'] as int;
                          final name = label['name'] as String;
                          final isDefault = id == 0;
                          final displayName =
                              isDefault && name.isEmpty ? '未分類' : name;
                          final isSelected = id == _selectedLabelId;
                          
                          // ★ バッジ機能（件数表示）をつけるとさらにリッチになります
                          final count = _clips.where((c) => (c['labelId'] ?? 0) == id).length;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedLabelId = id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? CupertinoColors.activeBlue
                                    : CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    displayName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? CupertinoColors.white
                                          : CupertinoColors.black,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (count > 0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '($count)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected ? CupertinoColors.white.withOpacity(0.8) : CupertinoColors.systemGrey,
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // ★ 2. 判定ロジックをシンプルに
                  if (filteredClips.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.heart,
                                size: 56, color: CupertinoColors.systemGrey3),
                            const SizedBox(height: 16),
                            Text(
                              _selectedLabelId == 0
                                  ? 'クリップはありません'
                                  : 'このラベルにクリップはありません',
                              style: const TextStyle(
                                fontSize: 16,
                                color: CupertinoColors.systemGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final clip = filteredClips[index];
                            return _buildClipItem(clip);
                          },
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
    final topicTitle = clip['topicTitle'] as String;
    final commentBody = clip['body'] as String;
    final commentNo = clip['no'] as int;
    final posted_at = clip['posted_at'] as String;
    final plus = clip['plus'] as int;
    final minus = clip['minus'] as int;
    final topicId = clip['topicId'] as int;
    final memo = clip['memo'] as String? ?? '';

    return GestureDetector(
      onLongPress: () => _showClipMenu(clip),
      onTap: () {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => TopicDetailScreen(
              topicId: topicId,
              title: topicTitle,
              commentCount: 0,
              posted_at: posted_at,
              initialJumpTo: commentNo, // ★ コメント番号を渡す
              saveReadPosition: false,  // ★ クリップからの遷移では既読位置を保存しない
            ),
          ),
        ).then((_) {
          // ★ 詳細から戻ってきたら再読込
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
            Text(
              topicTitle,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              commentBody,
              style: CupertinoTheme.of(context)
                  .textTheme
                  .textStyle
                  .copyWith(fontSize: 14),
            ),
            if (memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemYellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  memo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.black,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
                  children: [
                    Expanded(
                      child: Text(
                        'No.$commentNo • $posted_at • ＋$plus −$minus',
                        style: const TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.secondaryLabel,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Show anchor counts if present
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
                      child: const Icon(CupertinoIcons.xmark,
                          size: 18, color: CupertinoColors.secondaryLabel),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
