import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../utils/platform_helper.dart';
import 'topic_detail.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key});

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  List<Map<String, dynamic>> _clips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  Future<void> _loadClips() async {
    final clips = await getClippedComments();
    setState(() {
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
      PlatformHelper.showSnackBar(context, 'クリップを削除しました');
    }
  }

  Future<void> _refreshClips() async {
    setState(() => _loading = true);
    await _loadClips();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(child: PlatformHelper.buildLoadingIndicator());
    }

    if (_clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.heart,
              size: 64,
              color: CupertinoColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'クリップはまだありません',
              style: TextStyle(
                fontSize: 16,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'コメント右の❤️をタップして保存',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.tertiaryLabel,
              ),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _refreshClips,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _buildClipCard(context, _clips[i]),
              childCount: _clips.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClipCard(BuildContext context, Map<String, dynamic> clip) {
    final topicTitle = clip['topicTitle'] as String;
    final commentBody = clip['body'] as String;
    final commentNo = clip['no'] as int;
    final time = clip['time'] as String;
    final plus = clip['plus'] as int;
    final minus = clip['minus'] as int;
    final topicId = clip['topicId'] as int;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
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
          border: Border.all(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
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
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 14,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'No.$commentNo • $time • ＋$plus −$minus',
                    style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(4),
                  onPressed: () => _removeClip(clip),
                  child: const Icon(
                    CupertinoIcons.xmark,
                    size: 18,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
