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
  int _totalComments = 0;
  static const int _commentsPerPage = 500;
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
    if (!_scrollController.hasClients) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    // 下から 300px 以内でページング
    if (maxScroll - currentScroll < 300 && !_loadingMore && _hasMoreComments) {
      _loadMoreComments();
    }
  }
  
  // ===== 追加コメント読み込み =====
  Future<void> _loadMoreComments() async {
    if (_loadingMore) return;
    
    setState(() => _loadingMore = true);
    
    try {
      final offset = _displayedComments.length;
      debugPrint('📄 ページング: offset=$offset, limit=$_commentsPerPage');
      
      final result = await http.get(
        Uri.parse('${AppConfig.apiBase}/topic/${widget.topicId}').replace(
          queryParameters: {
            'offset': offset.toString(),
            'limit': _commentsPerPage.toString(),
          },
        ),
      );
      
      if (result.statusCode == 200) {
        final data = jsonDecode(result.body);
        final newComments = data['comments'] as List<dynamic>? ?? [];
        final total = data['total'] as int? ?? 0;
        
        debugPrint('✅ 取得: ${newComments.length}件, 合計: $total件');
        
        setState(() {
          _allComments.addAll(newComments);
          _displayedComments.addAll(newComments);
          _totalComments = total;
          _currentPage++;
          
          // すべて読み込んだかチェック
          _hasMoreComments = _displayedComments.length < total;
          
          debugPrint('📊 表示中のコメント: ${_displayedComments.length}/${_totalComments}');
        });
        
        // キャッシュに段階的に保存
        await CacheService.save('comments_${widget.topicId}', _allComments);
      }
    } catch (e) {
      debugPrint('❌ ページング読み込みエラー: $e');
    } finally {
      setState(() => _loadingMore = false);
    }
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

  // ===== APIからコメント取得（リフレッシュ時） =====
  Future<void> fetchComments() async {
    try {
      setState(() => _loading = true);
      
      // キャッシュをクリア
      _allComments.clear();
      _displayedComments.clear();
      _currentPage = 0;
      _totalComments = 0;
      
      final uri = Uri.parse('${AppConfig.apiBase}/topic/${widget.topicId}').replace(
        queryParameters: {
          'offset': '0',
          'limit': _commentsPerPage.toString(),
        },
      );
      
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newComments = data['comments'] as List<dynamic>? ?? [];
        final total = data['total'] as int? ?? newComments.length;

        debugPrint('🔄 リフレッシュ: ${newComments.length}/${total}件取得');

        setState(() {
          _allComments = newComments;
          _displayedComments = newComments;
          _totalComments = total;
          _hasMoreComments = newComments.length < total;
          _loading = false;
        });

        // キャッシュに保存
        await CacheService.save('comments_${widget.topicId}', _allComments);

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
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗: $e')),
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
    
    // 履歴状態とクリップ状態を取得
    final watchedIds = await getWatchedTopicIds();
    final clips = await getClippedComments();
    
    setState(() {
      _isWatched = watchedIds.contains(widget.topicId);
      _clippedCommentNos = clips
          .where((c) => c['topicId'] == widget.topicId)
          .map<int>((c) => c['no'] as int)
          .toSet();
    });
    
    // トピックを自動で履歴に追加
    if (!_isWatched) {
      await addWatchedTopicId(
        widget.topicId,
        title: widget.title,
        url: '',
        comments: widget.commentCount,
        time: '',
      );
      setState(() => _isWatched = true);
    }
    
    // キャッシュをチェック
    final cacheKey = 'comments_${widget.topicId}';
    final cached = await CacheService.load(cacheKey);
    
    if (cached.isNotEmpty) {
      // キャッシュがあれば最初の _commentsPerPage 件表示
      setState(() {
        _allComments = cached;
        _totalComments = cached.length;
        _displayedComments = cached.take(_commentsPerPage).toList();
        _currentPage = 0;
        _hasMoreComments = cached.length > _commentsPerPage;
        _loading = false;
      });
      
      debugPrint('📦 キャッシュから表示: ${_displayedComments.length}/${_totalComments}');
      
      // スクロール位置の復元
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && _savedOffset > 0) {
          _scrollController.jumpTo(_savedOffset);
        }
      });
    } else {
      // キャッシュがなければAPIから取得（最初の _commentsPerPage 件）
      await _fetchFirstPage();
    }
  }
  
  // ===== 最初のページ取得 =====
  Future<void> _fetchFirstPage() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBase}/topic/${widget.topicId}').replace(
        queryParameters: {
          'offset': '0',
          'limit': _commentsPerPage.toString(),
        },
      );
      
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newComments = data['comments'] as List<dynamic>? ?? [];
        final total = data['total'] as int? ?? newComments.length;
        
        debugPrint('🚀 初期読み込み: ${newComments.length}/${total}件');
        
        setState(() {
          _allComments = newComments;
          _displayedComments = newComments;
          _totalComments = total;
          _currentPage = 0;
          _hasMoreComments = newComments.length < total;
          _loading = false;
        });
        
        // キャッシュに保存
        await CacheService.save('comments_${widget.topicId}', _allComments);
      }
    } catch (e) {
      debugPrint('API Error: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('コメント読み込み失敗: $e')),
        );
      }
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

  // ===== 履歴（旧「お気に入り」） =====
  // 削除のみ対応（追加は自動）
  Future<void> _removeFromWatch() async {
    await removeWatchedTopicId(widget.topicId);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('履歴から削除しました')));
    setState(() => _isWatched = false);
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
    debugPrint('🔗 アンカークリック: No.$no');
    final index = _displayedComments.indexWhere((c) => c['no'] == no);
    debugPrint('📍 コメント インデックス: $index / 総数: ${_displayedComments.length}');
    if (index != -1) {
      // ListViewの場合、itemBuilderで各アイテムの高さが異なるため、
      // ここではスクロール位置を推定値で移動
      final estimatedOffset = index * 120.0; // 平均的なアイテム高さ
      debugPrint('📐 スクロール目標: $estimatedOffset');
      _scrollController.animateTo(
        estimatedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).catchError((_) {
        // スクロール範囲外の場合はジャンプ
        _scrollController.jumpTo(estimatedOffset);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No.$no へ移動しました')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントが見つかりません')),
      );
    }
  }

  // ===== アンカープレビュー =====
  void _showAnchorPreview(int no) {
    debugPrint('👀 アンカープレビュー: No.$no');
    final comment = _getCommentByNo(no);
    
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コメントが見つかりません')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          color: Colors.white,
          child: Column(
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'No.${comment['no']}  ${comment['time'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
              ),
              // コメント内容
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // アンカー表示
                        if ((comment['anchors'] as List?)?.isNotEmpty ?? false)
                          _buildAnchorText(List<int>.from(comment['anchors'] ?? [])),
                        if ((comment['reverse_anchors'] as List?)?.isNotEmpty ?? false)
                          _buildReverseAnchorText(List<int>.from(comment['reverse_anchors'] ?? [])),
                        // コメント本文
                        Text(
                          comment['body'] ?? '',
                          style: const TextStyle(fontSize: 15),
                        ),
                        // 画像
                        if (comment['image_url'] != null) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Image.network(
                                    comment['image_url'],
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
                                comment['image_url'],
                                height: 200,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        // プラス/マイナス/クリップ
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '＋${comment['plus'] ?? 0}',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '−${comment['minus'] ?? 0}',
                                  style: const TextStyle(color: Colors.blueGrey),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Icon(
                                _clippedCommentNos.contains(comment['no'])
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _clippedCommentNos.contains(comment['no'])
                                    ? Colors.pinkAccent
                                    : null,
                                size: 22,
                              ),
                              onPressed: () async {
                                await _toggleClip(comment);
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            onTap: () => _showAnchorPreview(no),
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
                  onTap: () => _showAnchorPreview(no),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            Text(
              'コメント: ${_displayedComments.length}/${_totalComments}件',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
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
                  itemCount: _displayedComments.length + (_loadingMore ? 1 : 0),
                  itemBuilder: (context, i) {
                    // 最後のアイテムが読み込み中インジケーター
                    if (i == _displayedComments.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 8),
                              Text(
                                '読み込み中... (${_displayedComments.length}/${_totalComments})',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final c = _displayedComments[i];
                    final no = c['no'] ?? '-';
                    final time = c['time'] ?? '';
                    final body = c['body'] ?? '';
                    final plus = c['plus'] ?? 0;
                    final minus = c['minus'] ?? 0;

                    final anchors = List<int>.from(c['anchors'] ?? []);
                    final reverseAnchors = List<int>.from(c['reverse_anchors'] ?? []);
                    
                    if (anchors.isNotEmpty || reverseAnchors.isNotEmpty) {
                      debugPrint('📌 No.$no - anchors: $anchors, reverse: $reverseAnchors');
                    }

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
