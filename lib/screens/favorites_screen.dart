import 'dart:developer';
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
    debugPrint('🔄 [Favorites] _loadWatchedTopics START');
    if (_inFlight) {
      debugPrint('⏭️ [Favorites] _loadWatchedTopics skipped: inFlight');
      return;
    }
    _inFlight = true;
    try {
      // 1. リスト取得
      final topics = await getWatchedTopics();
      
      // 2. watchedAt (最終閲覧日時) の新しい順にソート
      topics.sort((a, b) {
        final timeA = DateTime.tryParse(a['watchedAt'] ?? '') ?? DateTime(0);
        final timeB = DateTime.tryParse(b['watchedAt'] ?? '') ?? DateTime(0);
        // 降順（新しいのが上）
        return timeB.compareTo(timeA);
      });

      if (!mounted) {
        debugPrint('⚠️ [Favorites] _loadWatchedTopics: not mounted');
        return;
      }
      setState(() {
        _watchedTopics = topics;
        _loading = false;
      });
      debugPrint('✅ [Favorites] _loadWatchedTopics setState done, count=${topics.length}');
    } catch (e, st) {
      debugPrint('❌ [Favorites] _loadWatchedTopics error: $e\n$st');
      // エラー処理
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _inFlight = false;
      debugPrint('🔚 [Favorites] _loadWatchedTopics FINALLY');
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

  Future<void> _onDetailReturned() async {
    debugPrint('🔔 [Favorites] _onDetailReturned START');
    await _loadWatchedTopics();
    debugPrint('✅ [Favorites] _onDetailReturned END');
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

