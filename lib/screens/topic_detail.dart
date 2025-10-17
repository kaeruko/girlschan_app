import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import 'comment_post_webview.dart';

class TopicDetailScreen extends StatefulWidget {
  final int topicId;
  final String title;
  final int commentCount;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
    required this.title,
    required this.commentCount,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  List<dynamic> _comments = [];
  bool _loading = true;
  bool _isFavorite = false;
  final ScrollController _scrollController = ScrollController();
  double _savedOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _scrollController.dispose();
    super.dispose();
  }

  // ===== スクロール位置保存 =====
  Future<void> _saveScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('scroll_${widget.topicId}', _scrollController.offset);
  }

  Future<void> _loadScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    _savedOffset = prefs.getDouble('scroll_${widget.topicId}') ?? 0.0;
  }

  // ===== ローカル投稿保存 =====
  Future<void> _saveLocalComment(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_comments_${widget.topicId}';
    final existing = prefs.getStringList(key) ?? [];
    final newComment = {
      'no': _comments.length + 1,
      'body': text,
      'time': DateTime.now().toString().substring(0, 19),
      'plus': 0,
      'minus': 0,
      'name': '自分（投稿済）',
    };
    existing.add(jsonEncode(newComment));
    await prefs.setStringList(key, existing);
    setState(() => _comments.add(newComment));
  }

  Future<List<Map<String, dynamic>>> _loadLocalComments() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_comments_${widget.topicId}';
    final stored = prefs.getStringList(key) ?? [];
    return stored.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // ===== APIから取得 =====
  Future<void> fetchComments() async {
    try {
      final res = await http.get(Uri.parse('${AppConfig.apiBase}/topic/${widget.topicId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _comments = data['comments'];
      }
    } catch (e) {
      debugPrint('API Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ===== 初期化処理 =====
  Future<void> _load() async {
    await _loadScrollPosition();
    await fetchComments();
    final local = await _loadLocalComments();
    final favIds = await getFavoriteIds();
    setState(() {
      _comments.addAll(local);
      _isFavorite = favIds.contains(widget.topicId);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _savedOffset > 0) {
        _scrollController.jumpTo(_savedOffset);
      }
    });
  }

  // ===== 投稿ボタン =====
  Future<void> _openPostDialog() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('コメント入力'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'コメントを入力してください',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('確認')),
        ],
      ),
    );

    if (text == null || text.isEmpty) return;

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('投稿を確認'),
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('戻る')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('投稿')),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommentPostWebView(topicId: widget.topicId, text: text),
        ),
      );

      if (success == true) {
        await _saveLocalComment(text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('投稿を送信しました')),
        );
      }
    }
  }

  // ===== お気に入り =====
  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await removeFavoriteId(widget.topicId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('お気に入り解除しました')));
    } else {
      await addFavoriteId(widget.topicId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('お気に入りに追加しました')));
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPostDialog,
        child: const Icon(Icons.add_comment),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<ScrollEndNotification>(
              onNotification: (_) {
                _saveScrollPosition();
                return false;
              },
              child: RefreshIndicator(
                onRefresh: fetchComments,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _comments.length,
                  itemBuilder: (context, i) {
                    final c = _comments[i];
                    final no = c['no'] ?? '-';
                    final time = c['time'] ?? '';
                    final body = c['body'] ?? '';
                    final plus = c['plus'] ?? 0;
                    final minus = c['minus'] ?? 0;

                    return ListTile(
                      title: Text('No.$no  $time',
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(body, style: const TextStyle(fontSize: 15)),
                          if (c['image_url'] != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: Image.network(
                                      c['image_url'],
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  c['image_url'],
                                  height: 200,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: Icon(
                                        Icons.image_not_supported,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () async {
                                  // vbox{no} の形式でコメントIDを生成
                                  final commentId = 'vbox${no}';
                                  final success = await rateComment(widget.topicId, commentId, 1);
                                  if (success && mounted) {
                                    setState(() => c['plus'] = (c['plus'] ?? 0) + 1);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('プラスを送信しました')),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('＋$plus',
                                      style: const TextStyle(color: Colors.redAccent)),
                                ),
                              ),
                              InkWell(
                                onTap: () async {
                                  // vbox{no} の形式でコメントIDを生成
                                  final commentId = 'vbox${no}';
                                  final success = await rateComment(widget.topicId, commentId, -1);
                                  if (success && mounted) {
                                    setState(() => c['minus'] = (c['minus'] ?? 0) + 1);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('マイナスを送信しました')),
                                    );
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('−$minus',
                                      style: const TextStyle(color: Colors.blueGrey)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
