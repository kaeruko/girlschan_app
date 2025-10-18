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
    // 全件表示のため、追加読み込み不要
    // 今後、コメント数が非常に多い場合の最適化ポイント
  }

  // ===== スクロール位置保存 =====
  Future<void> _saveScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (_scrollController.hasClients) {
      await prefs.setDouble('scroll_${widget.topicId}', _scrollController.offset);
    }
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
        final newComments = data['comments'] ?? [];

        debugPrint('APIから取得したコメント数: ${newComments.length}');
        debugPrint('既存キャッシュコメント数: ${_allComments.length}');

        // 既にキャッシュから読み込んでいるなら、そこに新規コメントを追加
        // キャッシュから読み込んでいない場合はAPIのデータをそのまま使用
        List<dynamic> allComments;
        if (_allComments.isEmpty) {
          // 初回取得時はAPIのデータをそのまま使用
          allComments = newComments;
        } else {
          // 既存キャッシュがあれば、マージして更新
          allComments = _mergeComments(_allComments, newComments);
        }
        
        debugPrint('最終的なコメント数: ${allComments.length}');

        // 全コメントをキャッシュに保存
        await CacheService.save('comments_${widget.topicId}', allComments);

        setState(() {
          _allComments = allComments;
          _displayedComments = List.from(allComments); // 全件表示
          _currentPage = 0;
          _hasMoreComments = false; // ページング不要
          _loading = false;
        });

        // スクロール位置を復元
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients && _savedOffset > 0) {
              _scrollController.jumpTo(_savedOffset);
            }
          });
        }

        // 更新完了を通知
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('最新データを取得しました')),
          );
        }
      }
    } catch (e) {
      debugPrint('API Error: $e');
      // キャッシュがあればそれを使用
      final cached = await CacheService.load('comments_${widget.topicId}');
      setState(() {
        _allComments = cached;
        _displayedComments = List.from(cached); // 全件表示
        _currentPage = 0;
        _hasMoreComments = false;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通信に失敗しました（キャッシュを使用中）')),
        );
      }
    }
  }

  // ===== コメントをマージ（重複排除） =====
  List<dynamic> _mergeComments(List<dynamic> existing, List<dynamic> newComments) {
    // noをキーにしたMapを作成（既存のコメントから）
    final commentMap = <int, dynamic>{};
    for (var comment in existing) {
      final no = comment['no'] as int?;
      if (no != null) {
        commentMap[no] = comment;
      }
    }

    // 新しいコメントで更新・追加
    for (var comment in newComments) {
      final no = comment['no'] as int?;
      if (no != null) {
        commentMap[no] = comment; // 新しいデータで上書き
      }
    }

    // noの昇順でソート
    final sorted = commentMap.values.toList();
    sorted.sort((a, b) {
      final noA = (a['no'] as int?) ?? 0;
      final noB = (b['no'] as int?) ?? 0;
      return noA.compareTo(noB);
    });

    return sorted;
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
    
    // キャッシュをチェック
    final cacheKey = 'comments_${widget.topicId}';
    final cached = await CacheService.load(cacheKey);
    
    if (cached.isNotEmpty) {
      // キャッシュがあれば表示
      setState(() {
        _allComments = cached;
        _displayedComments = List.from(cached);
        _currentPage = 0;
        _hasMoreComments = false;
        _loading = false;
      });
      
      // スクロール位置の復元
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _savedOffset > 0) {
          _scrollController.jumpTo(_savedOffset);
        }
      });
    } else {
      // キャッシュがなければAPIから取得
      await fetchComments();
    }
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
      await addWatchedTopicId(
        widget.topicId,
        title: widget.title,
        url: '',
        comments: widget.commentCount,
        time: '',
      );
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

  // ===== アンカー関連 =====
  dynamic _getCommentByNo(int no) {
    try {
      return _displayedComments.firstWhere((c) => c['no'] == no);
    } catch (e) {
      return {};
    }
  }

  void _jumpToComment(int no) {
    final index = _displayedComments.indexWhere((c) => c['no'] == no);
    if (index != -1) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent + (index * 100.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No.$no へ移動しました')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントが見つかりません')),
      );
    }
  }

  Widget _buildAnchorText(List<int> anchors) {
    if (anchors.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Wrap(
        spacing: 4,
        children: anchors.map((no) {
          final referencedComment = _getCommentByNo(no);
          final isAvailable = referencedComment.isNotEmpty;
          
          return GestureDetector(
            onTap: isAvailable ? () => _jumpToComment(no) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.blue.shade100 : Colors.grey.shade200,
                border: Border.all(
                  color: isAvailable ? Colors.blue.shade300 : Colors.grey.shade300,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '>>$no',
                style: TextStyle(
                  fontSize: 12,
                  color: isAvailable ? Colors.blue.shade700 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReverseAnchorText(List<int> reverseAnchors) {
    if (reverseAnchors.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          const Text(
            '参照されている: ',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Expanded(
            child: Wrap(
              spacing: 4,
              children: reverseAnchors.take(5).map((no) {
                return GestureDetector(
                  onTap: () => _jumpToComment(no),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '<<$no',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (reverseAnchors.length > 5)
            Text(
              ' +${reverseAnchors.length - 5}件',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
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
                  itemCount: _displayedComments.length,
                  itemBuilder: (context, i) {
                    final c = _displayedComments[i];
                    final no = c['no'] ?? '-';
                    final time = c['time'] ?? '';
                    final body = c['body'] ?? '';
                    final plus = c['plus'] ?? 0;
                    final minus = c['minus'] ?? 0;

                    final anchors = List<int>.from(c['anchors'] ?? []);
                    final reverseAnchors = List<int>.from(c['reverse_anchors'] ?? []);

                    return ListTile(
                      title: Text('No.$no  $time',
                          style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (anchors.isNotEmpty)
                            _buildAnchorText(anchors),
                          if (reverseAnchors.isNotEmpty)
                            _buildReverseAnchorText(reverseAnchors),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
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
