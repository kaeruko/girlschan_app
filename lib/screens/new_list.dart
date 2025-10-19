import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/cache_service.dart';
import 'topic_detail.dart';

// キャッシュがあるトピックを表示するカスタムタイル
class _TopicTile extends StatefulWidget {
  final dynamic topic;

  const _TopicTile({required this.topic});

  @override
  State<_TopicTile> createState() => _TopicTileState();
}

class _TopicTileState extends State<_TopicTile> {
  bool _hasCachedComments = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    final hasCached = await CacheService.exists('comments_${widget.topic['id']}');
    setState(() {
      _hasCachedComments = hasCached;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _hasCachedComments 
            ? Colors.blue.withOpacity(0.05) 
            : Colors.transparent,
        border: _hasCachedComments
            ? Border(
                left: BorderSide(
                  color: Colors.blue,
                  width: 4,
                ),
              )
            : null,
      ),
      child: ListTile(
        leading: Stack(
          children: [
            Image.network(
              widget.topic['thumb'],
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
            ),
            if (_hasCachedComments)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          widget.topic['title'],
          style: TextStyle(
            fontSize: 15,
            fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.normal,
            color: _hasCachedComments ? Colors.blue[800] : null,
          ),
        ),
        subtitle: Text('${widget.topic['comments']}コメント • ${widget.topic['time']}'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TopicDetailScreen(
                topicId: widget.topic['id'],
                title: widget.topic['title'],
                commentCount: widget.topic['comments'],
              ),
            ),
          );
        },
      ),
    );
  }
}

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
    // キャッシュを読み込む（有効期限チェック済み）
    final cached = await CacheService.load(cacheKey);
    
    if (cached.isNotEmpty) {
      // キャッシュがあれば表示
      setState(() {
        _topics = cached;
        _loading = false;
      });
    } else {
      // キャッシュがなければAPIから取得
      await _fetchFromServer();
    }
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
      child: Scrollbar(
        child: ListView.builder(
          itemCount: _topics.length,
          itemBuilder: (context, i) {
            final t = _topics[i];
            return _TopicTile(topic: t);
          },
        ),
      ),
    );
  }
}
