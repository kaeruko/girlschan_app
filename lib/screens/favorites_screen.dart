import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with WidgetsBindingObserver {
  final _controller = TopicTileController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // タブが表示されるたびに再読み込み
    _loadWatchedTopics();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadWatchedTopics();
    }
  }

  Future<void> _loadWatchedTopics() async {
    final topics = await getWatchedTopics();
    setState(() {
      _watchedTopics = topics;
      _loading = false;
    });
  }

  Future<void> _refreshWatched() async {
    setState(() => _loading = true);
    await _loadWatchedTopics();
  }

  Future<void> _removeFromWatch(int topicId) async {
    await removeWatchedTopicId(topicId);
    setState(() {
      _watchedTopics.removeWhere((t) => t['id'] == topicId);
    });
    await _controller.refreshAll();
  }

  void _onDetailReturned() {
    // ここで何かしたければ（例：履歴リストの再読込など）
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: AppSpinner(size: 20));
    }
    if (_watchedTopics.isEmpty) {
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

    return Column(
      children: [
        // 更新ボタン（各ページ内に置く）
        Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minSize: 28,
            color: CupertinoColors.systemGrey5,
            onPressed: _refreshWatched,
            child: const Text('更新', style: TextStyle(fontSize: 12)),
          ),
        ),
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
