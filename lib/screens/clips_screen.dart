import 'package:flutter/material.dart';
import '../services/api_service.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クリップを削除しました')),
      );
    }
  }

  Future<void> _refreshClips() async {
    setState(() => _loading = true);
    await _loadClips();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'クリップはまだありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'コメント右の❤️をタップして保存',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshClips,
      child: ListView.builder(
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopicDetailScreen(
                      topicId: topicId,
                      title: topicTitle,
                      commentCount: 0,
                    ),
                  ),
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
                        color: Colors.grey,
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
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: () => _removeClip(clip),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
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
    );
  }
}
