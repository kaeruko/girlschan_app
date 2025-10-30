import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';

class TopicListScreen extends StatefulWidget {
  /// 'new' または 'popular' - どのトピックを表示するか
  final String sortOrder;

  const TopicListScreen({
    super.key,
    this.sortOrder = 'popular',
  });

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen>
    with WidgetsBindingObserver {
  late final String cacheKey;

  final _controller = TopicTileController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;
  bool _fetching = false; // ⭐ 多重実行防止フラグ

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // sortOrder に応じてキャッシュキーを切り替える
    cacheKey = widget.sortOrder == 'new' ? 'topics_new' : 'topics_popular';
    // logd('🔧 [initState] sortOrder=${widget.sortOrder}, cacheKey=$cacheKey', name: 'TopicList');
    _loadFromCache();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAll();
    }
  }

  Future<void> _loadFromCache() async {
    // logd('📂 [_loadFromCache] Loading topics from cache... (sortOrder=${widget.sortOrder}, cacheKey=$cacheKey)', name: 'TopicList');

    final cached = await CacheService.loadList(cacheKey);
    // logd('📂 [_loadFromCache] キャッシュ件数: ${cached.length} (cacheKey=$cacheKey)', name: 'TopicList');
    
    if (mounted && cached.isNotEmpty) {
      final topics = cached.cast<Map<String, dynamic>>();
      // logd('📂 [_loadFromCache] ✅ キャッシュから${topics.length}件のトピック読み込み完了', name: 'TopicList');
      for (int i = 0; i < topics.length && i < 3; i++) {
        // logd('  [${i + 1}] id=${topic['id']}, title=${topic['title']}, comments=${topic['comments']}', name: 'TopicList');
      }
      setState(() {
        _topics = topics;
        _loading = false;
      });
      await _controller.refreshAll();

      // ★ サイレント更新を削除 → キャッシュがあれば表示するだけ
      // 更新は「更新」ボタンまたは手動リフレッシュで実行
      return;
    }

    // キャッシュがない場合はサーバーから取得
    // logd('📂 [_loadFromCache] キャッシュなし → サーバーから取得', name: 'TopicList');
    await fetchFromServer();
  }

  Future<void> fetchFromServer() async {
    if (_fetching) {
      // logd('⏳ [fetchFromServer] スキップ（既に実行中）', name: 'TopicList');
      return;
    }
    _fetching = true;

    try {
      // logd('🌐 [fetchFromServer] API呼び出し開始 (sortOrder=${widget.sortOrder}, cacheKey=$cacheKey)', name: 'TopicList');
      
      final topics = widget.sortOrder == 'new'
          ? await fetchNewTopicsWithCache()
          : await fetchPopularTopicsWithCache();

      final list = topics.cast<Map<String, dynamic>>();
      // logd('🌐 [fetchFromServer] ✅ API取得完了: ${list.length}件のトピック', name: 'TopicList');
      for (int i = 0; i < list.length && i < 3; i++) {
        // logd('  [${i + 1}] id=${topic['id']}, title=${topic['title']}, comments=${topic['comments']}', name: 'TopicList');
      }
      
      // ⭐ watchedTopicsのコメント数を更新
      await updateWatchedTopicsComments(list);
      
      await CacheService.saveList(cacheKey, list);
      // logd('🌐 [fetchFromServer] 💾 キャッシュに保存完了', name: 'TopicList');

      if (!mounted) return;
      setState(() {
        _topics = list;
        _loading = false;
      });
      await _controller.refreshAll();
    } catch (e) {
      // logd('❌ [fetchFromServer] $e', name: 'TopicList');

      final cached = await CacheService.loadList(cacheKey);
      if (!mounted) return;
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
          logd('❌ [fetchFromServer] エラー時にキャッシュから${_topics.length}件読み込み', name: 'TopicList');
        }
        _loading = false;
      });
      await _controller.refreshAll();

      if (mounted) {
        await AppToast.show(context, 'データの更新に失敗しました（キャッシュを使用）');
      }
    } finally {
      _fetching = false; // ⭐ ロック解除
    }
  }

  Future<void> _removeCommentsCache(int topicId) async {
    // 一覧では「×」はコメントキャッシュ消去の意味にする
    await CacheService.clear('comments_$topicId');
    await _controller.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: const Center(child: AppSpinner(size: 20)),
      );
    }

    // logd('🎨 [TopicList.build] UI描画: ${_topics.length}件のトピック表示 (sortOrder=${widget.sortOrder}, cacheKey=$cacheKey)', name: 'TopicList');

    return Scaffold(
      body: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchFromServer,
                    child: CupertinoScrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _topics.length,
                        itemBuilder: (context, index) {
                          final topic = _topics[index];
                          // logd('🎨 [TopicList.itemBuilder] アイテム[$index]: id=${topic['id']}, title=${topic['title']}', name: 'TopicList');
                          return TopicTile(
                            topic: topic,
                            controller: _controller,
                            showThumb: true,                      // 一覧はサムネ表示
                            onRemoveIfCached: _removeCommentsCache, // ×でコメントキャッシュ削除
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
