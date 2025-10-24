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
      _loadWatchedTopics();
    }
  }

  Future<void> _loadWatchedTopics() async {
    if (_inFlight) return;  // ★ 既に読込中なら実行しない
    _inFlight = true;
    try {
      logd('📚 [_loadWatchedTopics] 履歴トピック読み込み開始', name: 'Favorites');
      final topics = await getWatchedTopics();
      logd('📚 [_loadWatchedTopics] ✅ 読み込み完了: ${topics.length}件', name: 'Favorites');
      
      for (int i = 0; i < topics.length && i < 5; i++) {
        final topic = topics[i];
        logd('  [${i + 1}] id=${topic['id']}, title=${topic['title']}, comments=${topic['comments']}', name: 'Favorites');
      }
      if (topics.length > 5) {
        logd('  ... 他 ${topics.length - 5}件', name: 'Favorites');
      }

      // もし時系列表示したいなら（存在するキー名に合わせて）
      // topics.sort((a, b) => DateTime.parse(b['watchedAt']).compareTo(DateTime.parse(a['watchedAt'])));

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
      _inFlight = false;  // ★ ロード終了
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
      logd('📚 [Favorites.build] 履歴トピックなし', name: 'Favorites');
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

    logd('📚 [Favorites.build] UI描画: ${_watchedTopics.length}件の履歴トピック表示', name: 'Favorites');

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
                  logd('📚 [Favorites.itemBuilder] アイテム[$i]: id=${topic['id']}, title=${topic['title']}', name: 'Favorites');
                  return TopicTile(
                    topic: topic,
                    controller: _controller,
                    showThumb: false,                   // 履歴はサムネ無しで軽量に
                    onRemoveIfCached: (id) async {      // ×で「履歴から外す」
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
