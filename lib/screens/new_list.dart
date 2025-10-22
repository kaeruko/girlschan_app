// lib/screens/new_list.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../widgets/inline_notice.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';

class NewListScreen extends StatefulWidget {
  const NewListScreen({super.key});

  @override
  State<NewListScreen> createState() => NewListScreenState();
}

class NewListScreenState extends State<NewListScreen>
    with WidgetsBindingObserver {
  static const String cacheKey = 'new_topics';

  final _controller = TopicTileController();

  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;
  String? _notice;
  bool _noticeIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// フォアグラウンド復帰で全タイル再評価
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.refreshAll();
    }
  }

  Future<void> _removeCommentsCache(int topicId) async {
    // 新着一覧では × はコメントキャッシュ削除の意味
    await CacheService.clear('comments_$topicId');
    await _controller.refreshAll();
  }

  Future<void> _load() async {
    // まずキャッシュ表示 → なければAPI
    logd('📂 [NewList._load] Load from cache', name: 'NewList');
    final cached = await CacheService.load(cacheKey);
    logd('📂 [NewList._load] cached=${cached.length}', name: 'NewList');

    if (cached.isNotEmpty) {
      setState(() {
        _topics = cached.cast<Map<String, dynamic>>();
        _loading = false;
      });
      await _controller.refreshAll();
    } else {
      await fetchFromServer();
    }
  }

  Future<void> fetchFromServer() async {
    try {
      logd('🌐 [NewList.fetchFromServer] GET /topics/new', name: 'NewList');
      final uri = Uri.parse('${AppConfig.apiBase}/topics/new');
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final data = jsonDecode(res.body) as List<dynamic>;
      final list = data.cast<Map<String, dynamic>>();

      await CacheService.save(cacheKey, list);
      if (!mounted) return;

      setState(() {
        _topics = list;
        _loading = false;
        _notice = null;
      });

      await _controller.refreshAll();
    } catch (e) {
      logd('❌ [NewList.fetchFromServer] $e', name: 'NewList');
      final cached = await CacheService.load(cacheKey);
      if (!mounted) return;
      setState(() {
        if (cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
        }
        _loading = false;
        _notice = '通信に失敗しました（キャッシュを使用）';
        _noticeIsError = true;
      });
      await _controller.refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: fetchFromServer,
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
            final t = _topics[i];
            return TopicTile(
              topic: t,
              controller: _controller,
              showThumb: true,
              onRemoveIfCached: _removeCommentsCache,
            );
          },
          itemCount: _topics.length,
        ),
      ],
    );
  }
}
