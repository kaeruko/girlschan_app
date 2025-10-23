import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../router/app_router.dart';
import '../widgets/common/app_spinner.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _clips = [];
  bool _loading = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadClips();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // タブが表示されるたびに再読み込み
    _loadClips();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadClips();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadClips() async {
    final clips = await getClippedComments();
    setState(() {
      // 新しい順（clipDate 降順）でソート
      clips.sort((a, b) {
        final dateA = DateTime.parse(a['clipDate'] as String);
        final dateB = DateTime.parse(b['clipDate'] as String);
        return dateB.compareTo(dateA);
      });
      _clips = clips;
      _loading = false;
    });
  }

  Future<void> _removeClip(Map<String, dynamic> clip) async {
    final topicId = clip['topicId'] as int;
    final commentNo = clip['no'] as int;
    
    await removeClippedComment(topicId, commentNo);
    
    if (mounted) {
      setState(() {
        _clips.removeWhere(
          (c) => c['topicId'] == topicId && c['no'] == commentNo,
        );
      });
    }
  }

  Future<void> _refreshClips() async {
    setState(() => _loading = true);
    await _loadClips();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: AppSpinner(size: 20));
    }

    if (_clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.heart, size: 64, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            Text('クリップに登録されたコメントはありません',
                style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey)),
            const SizedBox(height: 8),
            Text('コメント詳細の❤️をタップして登録',
                style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshClips,
      child: CupertinoScrollbar(
        controller: _scrollController,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _clips.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, i) {
            final clip = _clips[i];
            final topicTitle = clip['topicTitle'] as String;
            final commentBody = clip['body'] as String;
            final commentNo = clip['no'] as int;
            final time = clip['time'] as String;
            final plus = clip['plus'] as int;
            final minus = clip['minus'] as int;
            final topicId = clip['topicId'] as int;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: InkWell(
                onTap: () {
                  AppRouter.pushTopicDetail(
                    context,
                    topicId: topicId.toString(),
                    title: topicTitle,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // トピックタイトル
                      Text(
                        topicTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.systemGrey,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // コメント本文
                      Text(
                        commentBody,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    // 情報行（No・日時・評価）と削除ボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'No.$commentNo • $time • ＋$plus −$minus',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _removeClip(clip),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 18,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        ),
      ),
    );
  }
}
