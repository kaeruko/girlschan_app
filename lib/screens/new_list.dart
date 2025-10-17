import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/cache_service.dart';
import 'topic_detail.dart';

class NewListScreen extends StatefulWidget {
  const NewListScreen({super.key});

  @override
  State<NewListScreen> createState() => _NewListScreenState();
}

class _NewListScreenState extends State<NewListScreen> {
  List<dynamic> _topics = [];
  bool _loading = true;

  static const String cacheKey = 'new_topics';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // キャッシュの存在確認
    final hasCached = await CacheService.exists(cacheKey);
    
    if (hasCached) {
      // キャッシュがあれば表示
      await _loadFromCache();
    } else {
      // キャッシュがなければAPIから取得
      await _fetchFromServer();
    }
  }

  // キャッシュからデータを読み込む
  Future<void> _loadFromCache() async {
    final cached = await CacheService.load(cacheKey);
    setState(() {
      _topics = cached;
      _loading = false;
    });
  }

  // サーバーからデータを取得し、キャッシュを更新
  Future<void> _fetchFromServer() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiBase}/topics/new'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await CacheService.save(cacheKey, data);

        setState(() {
          _topics = data;
          _loading = false;
        });
      } else {
        throw Exception('HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('API Error: $e');
      // キャッシュがあればそれを使用
      final cached = await CacheService.load(cacheKey);
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached;
        }
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通信に失敗しました（キャッシュを使用中）')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchFromServer,
      child: ListView.builder(
        itemCount: _topics.length,
        itemBuilder: (context, i) {
          final t = _topics[i];
          return ListTile(
            leading: Image.network(
              t['thumb'],
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
            ),
            title: Text(t['title'], style: const TextStyle(fontSize: 15)),
            subtitle: Text('${t['comments']}コメント • ${t['time']}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TopicDetailScreen(
                    topicId: t['id'],
                    title: t['title'],
                    commentCount: t['comments'],
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
