import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/cache_service.dart';
import 'topic_detail.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  static const String cacheKey = 'topics';
  List<dynamic> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final cached = await CacheService.load(cacheKey);
      if (cached != null) {
        setState(() {
          _topics = cached;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('キャッシュの読み込みに失敗しました')),
        );
      }
    }
  }

  Future<void> _fetchFromServer() async {
    try {
      final data = await rootBundle.loadString('assets/mock_data/topics.json');
      final jsonResult = jsonDecode(data);

      await CacheService.save(cacheKey, jsonResult);

      setState(() {
        _topics = jsonResult;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データの更新に失敗しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GirlsChannel Offline')),
      body: RefreshIndicator(
        onRefresh: _fetchFromServer,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _topics.length,
                itemBuilder: (context, index) {
                  final topic = _topics[index];
                  return ListTile(
                    leading: Image.network(
                      topic['thumbnail'],
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.error),
                    ),
                    title: Text(topic['title']),
                    subtitle: Text(
                      '${topic['comments_count']}コメント • ${topic['created_at']}',
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TopicDetailScreen(
                            topicId: topic['id'],
                            title: topic['title'],
                            commentCount: topic['comments'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
