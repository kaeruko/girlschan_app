import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen>
    with WidgetsBindingObserver {
  static const String cacheKey = 'topics';

  final _controller = TopicTileController();

  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFromCache();
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

  Future<void> _loadFromCache() async {
    logd('📂 [_loadFromCache] Loading topics from cache...', name: 'TopicList');
    final cached = await CacheService.load(cacheKey);
    if (cached.isNotEmpty) {
      setState(() {
        _topics = cached.cast<Map<String, dynamic>>();
        _loading = false;
      });
      await _controller.refreshAll();
    } else {
      await _fetchFromServer();
    }
  }

  Future<void> _fetchFromServer() async {
    try {
      final topics = await fetchPopularTopicsWithCache();
      final list = topics.cast<Map<String, dynamic>>();
      await CacheService.save(cacheKey, list);
      if (!mounted) return;
      setState(() {
        _topics = list;
        _loading = false;
      });
      await _controller.refreshAll();
    } catch (e) {
      logd('❌ [_fetchFromServer] $e', name: 'TopicList');
      final cached = await CacheService.load(cacheKey);
      if (!mounted) return;
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
        }
        _loading = false;
      });
      await _controller.refreshAll();
      if (mounted) {
        await AppToast.show(context, 'データの更新に失敗しました（キャッシュを使用）');
      }
    }
  }

  Future<void> _removeCommentsCache(int topicId) async {
    // 一覧では「×」はコメントキャッシュ消去の意味にする
    await CacheService.clear('comments_$topicId');
    await _controller.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchFromServer,
        child: _loading
            ? const Center(child: AppSpinner(size: 20))
            : Scrollbar(
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: _topics.length,
                  itemBuilder: (context, index) {
                    final topic = _topics[index];
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
    );
  }
}
