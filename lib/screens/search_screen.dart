import 'package:flutter/material.dart';
import '../models/topic.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import 'topic_detail.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  List<Topic> _searchResults = [];
  bool _isLoading = false;
  String _currentQuery = '';
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query, {bool loadMore = false}) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentQuery = '';
        _currentPage = 1;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _currentPage = 1;
        _searchResults = [];
      }
    });

    try {
      print('🔍 検索開始: query=$query, page=$_currentPage');
      
      final result = await searchTopics(
        query: query,
        page: _currentPage,
        count: 50,
      );

      print('✅ API応答: ${result.keys}');
      
      final topics = (result['topics'] as List<dynamic>?)?.map((t) {
        print('📌 Topic JSON: $t');
        return Topic.fromJson(t as Map<String, dynamic>);
      }).toList() ?? [];
      
      print('📊 取得したトピック数: ${topics.length}');
      topics.forEach((t) => print('  - ${t.title}'));
      
      setState(() {
        _currentQuery = query;
        _totalCount = result['count'] ?? 0;
        
        if (loadMore) {
          _searchResults.addAll(topics);
        } else {
          _searchResults = topics;
        }
        
        _hasMore = _searchResults.length < _totalCount;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Search error: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('検索に失敗しました: $e')),
        );
      }
    }
  }

  void _loadMore() {
    if (!_isLoading && _hasMore && _currentQuery.isNotEmpty) {
      _currentPage++;
      _performSearch(_currentQuery, loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('検索'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '検索キーワード',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _currentQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
              onSubmitted: (value) {
                _performSearch(value);
              },
            ),
          ),
          if (_searchController.text.isNotEmpty && _currentQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _performSearch(_searchController.text);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('検索'),
                ),
              ),
            ),
          if (_currentQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '「$_currentQuery」の検索結果: $_totalCount件',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'キーワードを入力して検索',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    if (_isLoading && _searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('「$_currentQuery」に該当するトピックがありません'),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          // ローディングインジケータ（さらに読み込む）
          if (_hasMore) {
            _loadMore();
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            );
          }
          return const SizedBox.shrink();
        }

        final topic = _searchResults[index];
        return _buildTopicCard(context, topic);
      },
    );
  }

  Widget _buildTopicCard(BuildContext context, Topic topic) {
    print('🎨 カード描画: id=${topic.id}, title=${topic.title}, thumb=${topic.thumb}');
    
    return _SearchTopicCard(topic: topic);
  }
}

class _SearchTopicCard extends StatefulWidget {
  final Topic topic;

  const _SearchTopicCard({required this.topic});

  @override
  State<_SearchTopicCard> createState() => _SearchTopicCardState();
}

class _SearchTopicCardState extends State<_SearchTopicCard> {
  bool _hasCachedComments = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    if (widget.topic.id != null) {
      final hasCached = await CacheService.exists('comments_${widget.topic.id}');
      setState(() {
        _hasCachedComments = hasCached;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: _hasCachedComments 
          ? Colors.blue.withOpacity(0.05) 
          : null,
      child: InkWell(
        onTap: () {
          if (widget.topic.id != null) {
            print('📱 タップ: topicId=${widget.topic.id}');
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TopicDetailScreen(
                  topicId: widget.topic.id!,
                  title: widget.topic.title,
                  commentCount: widget.topic.comments,
                ),
              ),
            );
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左ボーダー（キャッシュある場合）
            if (_hasCachedComments)
              Container(
                width: 4,
                height: 80,
                color: Colors.blue,
              ),
            // サムネイル画像
            if (widget.topic.thumb != null && widget.topic.thumb!.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                    child: Image.network(
                      widget.topic.thumb!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[200],
                          child: const Center(child: SizedBox.shrink()),
                        );
                      },
                    ),
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
                          size: 14,
                        ),
                      ),
                    ),
                ],
              )
            else
              Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: Icon(Icons.image, color: Colors.grey[600]),
              ),
            // テキスト情報
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.topic.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.w500,
                        color: _hasCachedComments ? Colors.blue[800] : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.comment, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.topic.comments}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.topic.time,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
