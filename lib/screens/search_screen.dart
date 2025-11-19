import 'package:flutter/cupertino.dart';
// 他のimportはそのまま維持
import '../models/topic.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> with WidgetsBindingObserver {
  late TextEditingController _searchController;
  final _controller = TopicTileController();
  
  // スクロールコントローラーを保持
  final _scrollController = ScrollController();

  List<Topic> _searchResults = [];
  bool _isLoading = false;
  String _currentQuery = '';
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true; // 追加読み込みが可能かどうか

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    
    // ★ スクロールリスナーを登録
    _scrollController.addListener(_onScroll);

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ★ リスナーを解除してからdispose
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ★ スクロールイベントハンドラ
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // 最大スクロール位置
    final maxScroll = _scrollController.position.maxScrollExtent;
    // 現在のスクロール位置
    final currentScroll = _scrollController.position.pixels;

    // 下端から200px手前まで来たら、かつローディング中でなく、まだ続きがある場合
    if (maxScroll - currentScroll <= 200) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAll();
    }
  }

  Future<void> _performSearch(String query, {bool loadMore = false}) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentQuery = '';
        _currentPage = 1;
        _totalCount = 0;
        _hasMore = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _currentPage = 1;
        _searchResults = [];
        _hasMore = true; // 新規検索時はリセット
      }
    });

    try {
      final result = await searchTopics(
        query: query,
        page: _currentPage,
        count: 50,
      );

      // フラットな構造に対応: { "topics": [...], "total_count": 676 }
      final topicsList = result['topics'] as List<dynamic>? ?? [];
      
      final topics = topicsList
          .map((t) => Topic.fromJson(t as Map<String, dynamic>))
          .toList();
      
      // total_count はルートにある
      final total = result['total_count'] as int? ?? 0;
      setState(() {
        _currentQuery = query;
        _totalCount = total;

        if (loadMore) {
          _searchResults.addAll(topics);
        } else {
          _searchResults = topics;
        }

        // 取得した件数が総件数に達していれば false
        _hasMore = _searchResults.length < _totalCount;
        _isLoading = false;
      });

      // ログ確認用
      logd('取得完了: 現在${_searchResults.length}件 / 全$_totalCount件 (HasMore: $_hasMore)');

      await _controller.refreshAll();
    } catch (e) {
      logd('❌ Search error: $e', name: 'Search');
      setState(() => _isLoading = false);
      if (mounted) {
        await AppToast.show(context, '検索に失敗しました: $e');
      }
    }
  }

  void _loadMore() {
    // ガード条件: ロード中でない、かつ続きがある、かつクエリがある
    if (!_isLoading && _hasMore && _currentQuery.isNotEmpty) {
      logd('Load More Triggered: Page ${_currentPage + 1}');
      _currentPage++;
      _performSearch(_currentQuery, loadMore: true);
    }
  }

  // ... (_topicToMap, _buildTile は変更なしのため省略) ...
  Map<String, dynamic> _topicToMap(Topic t) => {
        'id': t.id,
        'title': t.title,
        'comments': t.comments,
        'posted_at': t.posted_at,
        'thumb': t.thumb,
      };

  Widget _buildTile(Topic t) {
    return TopicTile(
      topic: _topicToMap(t),
      controller: _controller,
      showThumb: true,
      showRemoveButton: true,
      onRemove: (id) async {
        await CacheService.clear('comments_$id');
        await _controller.refreshAll();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... (Navigationまわりは変更なしのため省略) ...
    final canSubmit = _searchController.text.isNotEmpty;

    return CupertinoPageScaffold(
      // ... (AppBar等はそのまま)
      navigationBar: const CupertinoNavigationBar(middle: Text('検索')),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // 検索バー
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: CupertinoTextField(
                  controller: _searchController,
                  placeholder: '検索キーワード',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(CupertinoIcons.search, color: CupertinoColors.systemGrey),
                  ),
                  suffix: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _currentQuery = '';
                              _totalCount = 0;
                              _hasMore = false;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(CupertinoIcons.xmark_circle_fill, color: CupertinoColors.systemGrey),
                          ),
                        )
                      : null,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (v) => _performSearch(v),
                ),
              ),
              
              // 件数表示など...
              if (_currentQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    '「$_currentQuery」の検索結果: $_totalCount件',
                    style: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                  ),
                ),

              Expanded(child: _buildResultsList()),
            ],
          ),
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
            const Text(
              'キーワードを入力して検索',
              style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // 初回ロード中
    if (_isLoading && _searchResults.isEmpty) {
      return const Center(child: AppSpinner(size: 20));
    }

    if (_searchResults.isEmpty) {
      return Center(child: Text('「$_currentQuery」に該当するトピックがありません'));
    }

    return CupertinoScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        // ★ hasMoreならローディング表示用に +1 する
        itemCount: _searchResults.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // 一番下の要素に到達したときの表示
          if (index == _searchResults.length) {
            // ★ ここで _loadMore() を呼ぶ必要はない（ScrollListenerが呼ぶため）
            // 単にローディング表示だけを行う
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: AppSpinner(size: 16)),
            );
          }

          final topic = _searchResults[index];
          return _buildTile(topic);
        },
      ),
    );
  }
}