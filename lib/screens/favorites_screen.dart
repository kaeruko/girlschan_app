import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import 'topic_detail.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<int> _watchedTopics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWatchedTopics();
  }

  Future<void> _loadWatchedTopics() async {
    final ids = await getWatchedTopicIds();
    setState(() {
      _watchedTopics = ids;
      _loading = false;
    });
  }

  Future<void> _refreshWatched() async {
    setState(() => _loading = true);
    await _loadWatchedTopics();
  }

  Future<void> _removeFromWatch(int topicId) async {
    await removeWatchedTopicId(topicId);
    setState(() {
      _watchedTopics.remove(topicId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ウォッチを削除しました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_watchedTopics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'ウォッチ中のトピックはありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'トピック詳細の📘をタップして登録',
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
      onRefresh: _refreshWatched,
      child: ListView.builder(
        itemCount: _watchedTopics.length,
        itemBuilder: (context, i) {
          final id = _watchedTopics[i];
          return ListTile(
            title: Text('トピックID: $id'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _removeFromWatch(id),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TopicDetailScreen(
                    topicId: id,
                    title: 'ウォッチ中のトピック $id',
                    commentCount: 0,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
