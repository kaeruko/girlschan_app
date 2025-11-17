import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';
import '../utils/log.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  final _controller = TopicTileController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;
  bool _refreshing = false;  // ★ リフレッシュスピナー用（_loading とは別）
  bool _inFlight = false;  // ★ 重複ロード防止

  /// ★ app_tab 側から叩くための公開メソッド
  void reloadFromOutside() {
    _loadWatchedTopics();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWatchedTopics();
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
      // _loadWatchedTopics();
    }
  }

Future<void> _loadWatchedTopics() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      // 1. SharedPreferences から基本リストを取得
      final topics = await getWatchedTopics();
      
      // 2. 各トピックについて、キャッシュファイルの最終更新日時を取得して埋め込む
      //    並列処理(Future.wait)にして高速化します
      await Future.wait(topics.map((topic) async {
        final int id = topic['id'];
        // キャッシュキー (topic_tile.dartの実装に合わせる)
        final cacheKey = 'comments_$id';
        
        // CacheServiceからファイルの更新日時を取得
        final modTime = await CacheService.getModifiedTime(cacheKey);
        
        // 一時的なキーとして保存 (UI表示用ではなくソート用)
        topic['_cache_updated_at'] = modTime;
      }));

      // 3. ソート実行
      //    優先順位: 
      //      1. キャッシュ更新日時が新しい順
      //      2. キャッシュがない場合は watchedAt (登録日時) が新しい順
      topics.sort((a, b) {
        final timeA = a['_cache_updated_at'] as DateTime?;
        final timeB = b['_cache_updated_at'] as DateTime?;

        // 両方にキャッシュがある場合 -> 新しい順
        if (timeA != null && timeB != null) {
          return timeB.compareTo(timeA);
        }

        // 片方だけキャッシュがある場合 -> キャッシュありを優先(上に来る)
        if (timeA != null) return -1;
        if (timeB != null) return 1;

        // 両方キャッシュがない場合 -> 登録日時(watchedAt)で比較
        final watchedA = DateTime.tryParse(a['watchedAt'] ?? '');
        final watchedB = DateTime.tryParse(b['watchedAt'] ?? '');
        
        if (watchedA != null && watchedB != null) {
          return watchedB.compareTo(watchedA);
        }
        
        return 0; // どちらも日時不明ならそのまま
      });

      if (!mounted) return;
      setState(() {
        _watchedTopics = topics;
        _loading = false;
      });
    } catch (e) {
      logd('❌ [_loadWatchedTopics] エラー: $e', name: 'Favorites');
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _refreshWatched() async {
    if (_refreshing || _inFlight) return;  // ★ ガード
    setState(() => _refreshing = true);
    await _loadWatchedTopics();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _removeFromWatch(int topicId) async {
    await removeWatchedTopicId(topicId);
    if (!mounted) return;  // ★ mounted ガード
    setState(() {
      _watchedTopics.removeWhere((t) => t['id'] == topicId);
    });
    await _controller.refreshAll();
  }

  void _onDetailReturned() {
    // ★ 詳細から戻ったら再読込
    _loadWatchedTopics();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: AppSpinner(size: 20));
    }
    if (_watchedTopics.isEmpty) {
      // //logd('📚 [Favorites.build] 履歴トピックなし', name: 'Favorites');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.bookmark, size: 64, color: CupertinoColors.systemGrey),
            const SizedBox(height: 16),
            Text('履歴に登録されたトピックはありません',
                style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey)),
            const SizedBox(height: 8),
            Text('トピック詳細の📘をタップして登録',
                style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
          ],
        ),
      );
    }

    // //logd('📚 [Favorites.build] UI描画: ${_watchedTopics.length}件の履歴トピック表示', name: 'Favorites');

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshWatched,
            child: CupertinoScrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _watchedTopics.length,
                itemBuilder: (context, i) {
                  final topic = _watchedTopics[i];
                  return TopicTile(
                    topic: topic,
                    controller: _controller,
                    showThumb: false,                   // 履歴はサムネ無しで軽量に
                    showRemoveButton: true,
                    removeButtonAlwaysVisible: true,
                    onRemove: (id) async {              // ×で「履歴から外す」
                      await _removeFromWatch(id);
                    },
                    onAfterPop: _onDetailReturned,      // 詳細から戻ったフック
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

