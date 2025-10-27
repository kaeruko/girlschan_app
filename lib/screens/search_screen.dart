// lib/screens/search_screen.dart
import 'package:flutter/cupertino.dart';

import '../models/topic.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';

// 共通タイル
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
  final _scrollController = ScrollController();

  // 検索状態
  List<Topic> _searchResults = [];
  bool _isLoading = false;
  String _currentQuery = '';
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
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
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAll();
    }
  }

  /// タブから呼ばれるメソッド：クエリを設定して検索開始
  void setQueryAndSearch(String q) {
    _searchController.text = q;
    _performSearch(q);
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
      }
    });

    try {
      final result = await searchTopics(
        query: query,
        page: _currentPage,
        count: 50,
      );

      final topics = (result['topics'] as List<dynamic>? ?? [])
          .map((t) => Topic.fromJson(t as Map<String, dynamic>))
          .toList();

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

      // 表示直後に各タイルのキャッシュ状態を反映
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
    if (!_isLoading && _hasMore && _currentQuery.isNotEmpty) {
      _currentPage++;
      _performSearch(_currentQuery, loadMore: true);
    }
  }

  // Topic -> Map 変換（TopicTile へのアダプタ）
  Map<String, dynamic> _topicToMap(Topic t) => {
        'id': t.id,
        'title': t.title,
        'comments': t.comments,
        'posted_at': t.posted_at,
        'thumb': t.thumb,
      };

  // 検索結果リストの1行を共通タイルで描画
  Widget _buildTile(Topic t) {
    return TopicTile(
      topic: _topicToMap(t),
      controller: _controller,
      showThumb: true,                 // 検索結果はサムネ表示
      // 検索画面の「×」はコメントキャッシュ削除にしておく（任意）
      onRemoveIfCached: (id) async {
        await CacheService.clear('comments_$id');
        await _controller.refreshAll();
      },
      // 詳細から戻った直後のフック（必要なら何かする）
      onAfterPop: () {
        // 例: 検索結果の再フェッチ等、今は何もしない
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _searchController.text.isNotEmpty;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('検索'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 検索入力
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

            if (canSubmit && _currentQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: CupertinoColors.systemBlue,
                    onPressed: () => _performSearch(_searchController.text),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(CupertinoIcons.search, color: CupertinoColors.white),
                        SizedBox(width: 8),
                        Text('検索', style: TextStyle(color: CupertinoColors.white)),
                      ],
                    ),
                  ),
                ),
              ),

            if (_currentQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  '「$_currentQuery」の検索結果: $_totalCount件',
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),

            // 結果リスト
            Expanded(child: _buildResultsList()),
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
            const Text(
              'キーワードを入力して検索',
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

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
        itemCount: _searchResults.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _searchResults.length) {
            // ページングのローディング行
            _loadMore();
            return const Padding(
              padding: EdgeInsets.all(16.0),
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
