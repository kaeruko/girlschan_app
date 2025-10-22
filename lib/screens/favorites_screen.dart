import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../config/app_config.dart';
import '../utils/log.dart';
import '../widgets/inline_notice.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with WidgetsBindingObserver {
  final _controller = TopicTileController();
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWatchedTopics();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAll();
    }
  }

  Future<void> _loadWatchedTopics() async {
    final topics = await getWatchedTopics();
    // 「保存順の逆」にしたいならここで反転
    final reversed = topics.reversed.toList();
    setState(() {
      _watchedTopics = reversed;
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
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_watchedTopics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.bookmark,
              size: 64,
              color: CupertinoColors.systemGrey3,
            ),
            const SizedBox(height: 16),
            const Text(
              '履歴に登録されたトピックはありません',
              style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey),
            ),
            const SizedBox(height: 8),
            const Text(
              'トピック詳細の📘をタップして登録',
              style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey2),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _refreshWatched,
        ),
        if (_notice != null)
          SliverToBoxAdapter(
            child: InlineNotice(
              text: _notice!,
              isError: _noticeIsError,
              onClose: () => setState(() => _notice = null),
            ),
          ),
        SliverList.builder(
          itemBuilder: (context, i) {
            final topic = _watchedTopics[i];
            return TopicTile(
              topic: topic,
              controller: _controller,
              showThumb: false,
              onRemoveIfCached: (id) async {
                await _removeFromWatch(id);
              },
              onAfterPop: _onDetailReturned,
            );
          },
          itemCount: _watchedTopics.length,
        ),
      ],
    );
  }
}
