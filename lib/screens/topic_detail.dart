import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
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
  List<dynamic> _allComments = []; // 全コメント（キャッシュ用）
  List<dynamic> _displayedComments = []; // 表示中のコメント
  bool _loading = true;
  bool _loadingMore = false;
  bool _isWatched = false;
  bool _hasMoreComments = true;
  int _currentPage = 0;
  static const int _commentsPerPage = 100;
  final ScrollController _scrollController = ScrollController();
  double _savedOffset = 0.0;
  Set<int> _clippedCommentNos = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _saveScrollPosition();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ===== スクロール検知（追加読み込み） =====
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // 下から500pxの位置に達したら次ページを読み込み
      if (!_loadingMore && _hasMoreComments) {
        _loadMoreComments();
      }
    }
  }

  // ===== スクロール検知（追加読み込み） =====
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 500) {
      // 下から500pxの位置に達したら次ページを読み込み
      if (!_loadingMore && _hasMoreComments) {
        _loadMoreComments();
      }
    }
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
      'no': _displayedComments.length + 1,
      'body': text,
      'time': DateTime.now().toString().substring(0, 19),
      'plus': 0,
      'minus': 0,
      'name': '自分（投稿済）',
    };
    existing.add(jsonEncode(newComment));
    await prefs.setStringList(key, existing);
    setState(() => _displayedComments.add(newComment));
  }

  Future<List<Map<String, dynamic>>> _loadLocalComments() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_comments_${widget.topicId}';
    final stored = prefs.getStringList(key) ?? [];
    return stored.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  // ===== APIから全コメント取得 =====
  Future<void> fetchComments() async {
    try {
      final res =
          await http.get(Uri.parse('${AppConfig.apiBase}/topic/${widget.topicId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final allComments = data['comments'] ?? [];

        // コメントをキャッシュに保存
        await CacheService.save('comments_${widget.topicId}', allComments);

        setState(() {
          _allComments = allComments;
          _displayedComments = [];
          _currentPage = 0;
          _hasMoreComments = true;
          // 最初のページ分を追加
          _addPageOfComments();
          _loading = false;
        });

        // リフレッシュ後のスクロール復元
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && _savedOffset > 0) {
              _scrollController.jumpTo(_savedOffset);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('API Error: $e');
      // キャッシュがあればそれを使用
      final cached = await CacheService.load('comments_${widget.topicId}');
      setState(() {
        _allComments = cached;
        _displayedComments = [];
        _currentPage = 0;
        _hasMoreComments = true;
        if (cached.isNotEmpty) {
          _addPageOfComments();
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

  // ===== 次ページのコメント読み込み =====
  Future<void> _loadMoreComments() async {
    if (_loadingMore || !_hasMoreComments) return;

    setState(() => _loadingMore = true);

    try {
      // 少し遅延させてUX向上
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _addPageOfComments();
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('Error loading more comments: $e');
      setState(() => _loadingMore = false);
    }
  }

  // ===== ページ分のコメントを追加 =====
  void _addPageOfComments() {
    final start = _currentPage * _commentsPerPage;
    final end = start + _commentsPerPage;

    if (start >= _allComments.length) {
      _hasMoreComments = false;
      return;
    }

    final pageComments = _allComments.length > end
        ? _allComments.sublist(start, end)
        : _allComments.sublist(start);

    _displayedComments.addAll(pageComments);
    _currentPage++;

    // 全コメントを読み込んだかチェック
    if (_displayedComments.length >= _allComments.length) {
      _hasMoreComments = false;
    }
  }

  // ===== 初期化処理 =====
  Future<void> _load() async {
    await _loadScrollPosition();
    
    // ウォッチ状態とクリップ状態を取得
    final watchedIds = await getWatchedTopicIds();
    final clips = await getClippedComments();
    
    setState(() {
      _isWatched = watchedIds.contains(widget.topicId);
      _clippedCommentNos = clips
          .where((c) => c['topicId'] == widget.topicId)
          .map<int>((c) => c['no'] as int)
          .toSet();
    });
    
    // 常にAPIから全件取得する
    await fetchComments();

    // スクロール位置の復元
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

  // ===== ウォッチ（旧「お気に入り」） =====
  Future<void> _toggleWatch() async {
    if (_isWatched) {
      await removeWatchedTopicId(widget.topicId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ウォッチを解除しました')));
    } else {
      await addWatchedTopicId(widget.topicId);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ウォッチに追加しました')));
    }
    setState(() => _isWatched = !_isWatched);
  }

  // ===== クリップ（コメント保存） =====
  Future<void> _toggleClip(Map<String, dynamic> comment) async {
    final no = comment['no'] as int;
    final isClipped = _clippedCommentNos.contains(no);
    
    if (isClipped) {
      await removeClippedComment(widget.topicId, no);
      _clippedCommentNos.remove(no);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('クリップを解除しました')));
    } else {
      await addClippedComment(
        topicId: widget.topicId,
        topicTitle: widget.title,
        commentNo: no,
        commentBody: comment['body'] ?? '',
        time: comment['time'] ?? '',
        plus: comment['plus'] ?? 0,
        minus: comment['minus'] ?? 0,
      );
      _clippedCommentNos.add(no);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('クリップに保存しました')));
    }
    setState(() {});
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(_isWatched ? Icons.bookmark : Icons.bookmark_border),
            tooltip: _isWatched ? 'ウォッチ中' : 'ウォッチに追加',
            onPressed: _toggleWatch,
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
                  itemCount: _displayedComments.length +
                      (_loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    // ローディング表示
                    if (i == _displayedComments.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final c = _displayedComments[i];
                    final no = c['no'] ?? '-';
                    final time = c['time'] ?? '';
                    final body = c['body'] ?? '';
                    final plus = c['plus'] ?? 0;
                    final minus = c['minus'] ?? 0;

                    return ListTile(
                      title: Text('No.$no  $time',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey)),
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
                                      errorBuilder: (context, error,
                                              stackTrace) =>
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
                                  loadingBuilder: (context, child,
                                      loadingProgress) {
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
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () async {
                                      // vbox{no} の形式でコメントIDを生成
                                      final commentId = 'vbox${no}';
                                      final success = await rateComment(
                                          widget.topicId, commentId, 1);
                                      if (success && mounted) {
                                        setState(() =>
                                            c['plus'] =
                                                (c['plus'] ?? 0) + 1);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'プラスを送信しました')),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('＋$plus',
                                          style: const TextStyle(
                                              color: Colors.redAccent)),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      // vbox{no} の形式でコメントIDを生成
                                      final commentId = 'vbox${no}';
                                      final success = await rateComment(
                                          widget.topicId, commentId, -1);
                                      if (success && mounted) {
                                        setState(() =>
                                            c['minus'] =
                                                (c['minus'] ?? 0) + 1);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'マイナスを送信しました')),
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('−$minus',
                                          style: const TextStyle(
                                              color: Colors.blueGrey)),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(
                                  _clippedCommentNos.contains(no)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: _clippedCommentNos.contains(no)
                                      ? Colors.pinkAccent
                                      : null,
                                  size: 22,
                                ),
                                onPressed: () => _toggleClip(c),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
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
