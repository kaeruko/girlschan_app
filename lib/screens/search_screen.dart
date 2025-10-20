import 'package:flutter/cupertino.dart';
import '../models/topic.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/platform_helper.dart';
import 'topic_detail.dart';

// グローバルキー管理用クラス
class _SearchTopicCardController {
  final Set<_SearchTopicCardState> _cards = {};

  void register(_SearchTopicCardState card) {
    _cards.add(card);
  }

  void unregister(_SearchTopicCardState card) {
    _cards.remove(card);
  }

  void refreshAll() {
    for (var card in _cards) {
      card._checkCache();
    }
  }
}

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with WidgetsBindingObserver {
  late TextEditingController _searchController;
  List<Topic> _searchResults = [];
  bool _isLoading = false;
  String _currentQuery = '';
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true;
  late _SearchTopicCardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _SearchTopicCardController();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻ったときに全カードを再チェック
      _controller.refreshAll();
    }
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
        PlatformHelper.showSnackBar(context, '検索に失敗しました: $e');
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('検索'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSearchTextField(
                controller: _searchController,
                placeholder: '検索キーワード',
                onChanged: (value) {
                  setState(() {});
                },
                onSubmitted: (value) {
                  _performSearch(value);
                },
                onSuffixTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                    _currentQuery = '';
                  });
                },
              ),
            ),
            if (_searchController.text.isNotEmpty && _currentQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      _performSearch(_searchController.text);
                    },
                    child: const Text('検索'),
                  ),
                ),
              ),
            if (_currentQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  '「$_currentQuery」の検索結果: $_totalCount件',
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ),
            Expanded(
              child: _buildResultsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.search, size: 64, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            Text(
              'キーワードを入力して検索',
              style: CupertinoTheme.of(context).textTheme.textStyle,
            ),
          ],
        ),
      );
    }

    if (_isLoading && _searchResults.isEmpty) {
      return Center(child: PlatformHelper.buildLoadingIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('「$_currentQuery」に該当するトピックがありません'),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _searchResults.length) {
                // ローディングインジケータ（さらに読み込む）
                if (_hasMore) {
                  _loadMore();
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: PlatformHelper.buildLoadingIndicator(),
                  );
                }
                return const SizedBox.shrink();
              }

              final topic = _searchResults[index];
              return _buildTopicCard(context, topic);
            },
            childCount: _searchResults.length + (_hasMore ? 1 : 0),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicCard(BuildContext context, Topic topic) {
    print('🎨 カード描画: id=${topic.id}, title=${topic.title}, thumb=${topic.thumb}');
    
    return _SearchTopicCard(topic: topic, controller: _controller);
  }
}

class _SearchTopicCard extends StatefulWidget {
  final Topic topic;
  final _SearchTopicCardController controller;

  const _SearchTopicCard({
    required this.topic,
    required this.controller,
  });

  @override
  State<_SearchTopicCard> createState() => _SearchTopicCardState();
}

class _SearchTopicCardState extends State<_SearchTopicCard> {
  bool _hasCachedComments = false;

  @override
  void initState() {
    super.initState();
    widget.controller.register(this);
    _checkCache();
  }

  @override
  void dispose() {
    widget.controller.unregister(this);
    super.dispose();
  }

  Future<void> _checkCache() async {
    if (widget.topic.id != null) {
      final hasCached = await CacheService.exists('comments_${widget.topic.id}');
      if (mounted) {
        setState(() {
          _hasCachedComments = hasCached;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.topic.id != null) {
          print('📱 タップ: topicId=${widget.topic.id}');
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => TopicDetailScreen(
                topicId: widget.topic.id!,
                title: widget.topic.title,
                commentCount: widget.topic.comments,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: _hasCachedComments 
              ? CupertinoColors.systemBlue.withOpacity(0.05) 
              : CupertinoColors.systemBackground,
          border: Border(
            left: _hasCachedComments
                ? BorderSide(color: CupertinoColors.systemBlue, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // サムネイル画像
            if (widget.topic.thumb != null && widget.topic.thumb!.isNotEmpty)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(_hasCachedComments ? 4 : 0),
                      bottomLeft: Radius.circular(_hasCachedComments ? 4 : 0),
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
                          color: CupertinoColors.systemGrey5,
                          child: Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey3),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 80,
                          height: 80,
                          color: CupertinoColors.systemGrey6,
                          child: Center(child: PlatformHelper.buildLoadingIndicator()),
                        );
                      },
                    ),
                  ),
                  if (_hasCachedComments)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          CupertinoIcons.check_mark,
                          color: CupertinoColors.white,
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
                color: CupertinoColors.systemGrey5,
                child: Icon(CupertinoIcons.photo, color: CupertinoColors.systemGrey3),
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
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontWeight: _hasCachedComments ? FontWeight.w600 : FontWeight.w500,
                        color: _hasCachedComments ? CupertinoColors.systemBlue : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(CupertinoIcons.bubble_left, size: 14, color: CupertinoColors.systemGrey),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.topic.comments}',
                          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.topic.time,
                            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel,
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
