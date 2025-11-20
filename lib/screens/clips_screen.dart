import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../screens/topic_detail.dart';
import '../widgets/common/app_spinner.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // RouteAware を使わずに .then() コールバックで検知
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
    if (_inFlight) return;  // ★ 既に読込中なら実行しない
    _inFlight = true;
    try {
      final clips = await getClippedComments();
      
      // ★ パース失敗時のフォールバック付き
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
        _loading = false;
      });
  } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _clips = [];
      });
    } finally {
      _inFlight = false;  // ★ ロード終了
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _loadClips();
    if (mounted) setState(() => _refreshing = false);
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
    return CupertinoPageScaffold(
      navigationBar: null,
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: AppSpinner(size: 20))
            : CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // ← MaterialのRefreshIndicatorの代わり
                  CupertinoSliverRefreshControl(onRefresh: _refresh),

                  if (_clips.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(CupertinoIcons.heart,
                                size: 56,
                                color: CupertinoColors.systemGrey3),
                            SizedBox(height: 12),
                            Text('クリップはまだありません',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: CupertinoColors.systemGrey)),
                            SizedBox(height: 6),
                            Text('コメント右の ❤️ をタップして保存',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.systemGrey2)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildClipItem(context, _clips[i]),
                        childCount: _clips.length,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildClipItem(BuildContext context, Map<String, dynamic> clip) {
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
          if (mounted) _loadClips();
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
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
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

