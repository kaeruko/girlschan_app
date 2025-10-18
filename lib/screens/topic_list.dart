import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/cache_service.dart';
import '../services/api_service.dart';
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
      } else {
        await _fetchFromServer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('キャッシュの読み込みに失敗しました')),
        );
      }
      await _fetchFromServer();
    }
  }

  Future<void> _fetchFromServer() async {
    try {
      final topics = await fetchNewTopics();
      await CacheService.save(cacheKey, topics);

      setState(() {
        _topics = topics;
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
      appBar: AppBar(title: const Text('がるちゃんあぷり')),
      body: RefreshIndicator(
        onRefresh: _fetchFromServer,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _topics.length,
                itemBuilder: (context, index) {
                  final topic = _topics[index];
                  return ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      child: topic['thumbnail'] != null
                          ? Image.network(
                              topic['thumbnail'],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.image_not_supported,
                                size: 30,
                                color: Colors.grey,
                              ),
                            )
                          : const Icon(
                              Icons.image_not_supported,
                              size: 30,
                              color: Colors.grey,
                            ),
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
