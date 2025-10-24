  // import 'package:flutter/material.dart';  // ← 消す
  import 'package:flutter/cupertino.dart';
  import '../services/api_service.dart';
  import '../screens/topic_detail.dart';
  import '../widgets/common/app_spinner.dart';

  class ClipsScreen extends StatefulWidget {
    const ClipsScreen({super.key});
    @override
    State<ClipsScreen> createState() => _ClipsScreenState();
  }

  class _ClipsScreenState extends State<ClipsScreen> with WidgetsBindingObserver {
    final _scrollController = ScrollController();
    List<Map<String, dynamic>> _clips = [];
    bool _loading = true;
    bool _refreshing = false;

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
      try {
        print('[ClipsScreen] Loading clips...');
        final clips = await getClippedComments();
        print('[ClipsScreen] Clips loaded: ${clips.length} items');
        print('[ClipsScreen] Clips data: $clips');
        
        clips.sort((a, b) =>
            DateTime.parse(b['clipDate'] as String)
                .compareTo(DateTime.parse(a['clipDate'] as String)));
        
        if (!mounted) return;
        setState(() {
          _clips = clips;
          _loading = false;
          print('[ClipsScreen] State updated. _loading=$_loading, _clips.length=${_clips.length}');
        });
      } catch (e, stackTrace) {
        print('[ClipsScreen] ERROR: $e');
        print('[ClipsScreen] StackTrace: $stackTrace');
        if (!mounted) return;
        setState(() {
          _loading = false;
          _clips = [];
        });
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

    @override
    Widget build(BuildContext context) {
      print('[ClipsScreen] build() called. _loading=$_loading, _clips.length=${_clips.length}');
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

                    // 右上に小さな「更新」
                    SliverToBoxAdapter(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minSize: 28,
                          color: CupertinoColors.systemGrey5,
                          onPressed: _refresh,
                          child: _refreshing
                              ? const CupertinoActivityIndicator(radius: 8)
                              : const Text('更新', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),

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
                      SliverList.builder(
                        itemCount: _clips.length,
                        itemBuilder: (context, i) =>
                            _buildClipItem(context, _clips[i]),
                      ),
                  ],
                ),
        ),
      );
    }

    Widget _buildClipItem(BuildContext context, Map<String, dynamic> clip) {
      print('[ClipsScreen] _buildClipItem: clip=$clip');
      final topicTitle = clip['topicTitle'] as String;
      final commentBody = clip['body'] as String;
      final commentNo = clip['no'] as int;
      final time = clip['time'] as String;
      final plus = clip['plus'] as int;
      final minus = clip['minus'] as int;
      final topicId = clip['topicId'] as int;

      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: topicId,
                title: topicTitle,
                commentCount: 0,
              ),
            ),
          );
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'No.$commentNo • $time • ＋$plus −$minus',
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
