import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../services/cache_service.dart';
import '../services/api_service.dart';
import '../utils/log.dart';
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
      print('');
      print('🔄 _loadFromCache() 開始');
      final cached = await CacheService.load(cacheKey);
      print('🔄 キャッシュ確認: ${cached != null ? 'あり (${(cached as List?)?.length ?? 0}件)' : 'なし'}');
      
      if (cached != null) {
        setState(() {
          _topics = cached;
          _loading = false;
        });
        print('🔄 キャッシュから読み込み完了');
      } else {
        print('🔄 キャッシュなし、サーバーから取得開始');
        await _fetchFromServer();
      }
    } catch (e) {
      print('🔄 キャッシュ読み込みエラー: $e');
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
      print('');
      print('🌐 _fetchFromServer() 開始');
      final topics = await fetchNewTopics();
      print('🌐 API取得成功: ${topics.length}件');
      await CacheService.save(cacheKey, topics);
      print('🌐 キャッシュ保存完了');

      setState(() {
        _topics = topics;
        _loading = false;
      });
      print('🌐 UI更新完了');
    } catch (e) {
      print('🌐 _fetchFromServer() エラー: $e');
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
                      child: topic['thumb'] != null
                          ? Image.network(
                              topic['thumb'],
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
                      '${topic['comments']}コメント • ${topic['time']}',
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
