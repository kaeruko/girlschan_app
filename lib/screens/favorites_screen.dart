import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../app/app_tabs.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';
import '../utils/log.dart';
import '../screens/topic_detail.dart';

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
  bool _metaUpdating = false; // ★ メタ更新ジョブが走っているかどうか

  /// ★ app_tab 側から叩くための公開メソッド
  void reloadFromOutside() {
    _loadWatchedTopics();
  }

  DateTime? parseGirlsChanPostedAt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1) 「〜前」は全部「最近」とみなす（fetch対象）
    //    → dat落ち判定には使わないので、敢えて now を返してOK
    if (s.contains('前')) {
      return DateTime.now();
    }

    // 2) "2025/11/18(火) 18:37" みたいな形式をパース
    //    年/月/日(…)? 時:分 を拾う
    final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2}).*?(\d{1,2}):(\d{2})')
        .firstMatch(s);
    if (m != null) {
      final year = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      final hour = int.parse(m.group(4)!);
      final minute = int.parse(m.group(5)!);
      return DateTime(year, month, day, hour, minute);
    }

    // 3) それ以外はよくわからないので「最近」とみなして fetch させたいなら
    //    null ではなく now を返しておいてもいい
    return DateTime.now();
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
    if (_refreshing || _inFlight) return;  // ガード
    setState(() => _refreshing = true);

    // まずローカルの履歴を読み直して UI を最新にする
    await _loadWatchedTopics();

    if (mounted) setState(() => _refreshing = false);

    // メタ情報更新は UI とは独立して裏側でゆっくり回す
    _startBackgroundMetaUpdate();
  }

  Future<void> _removeFromWatch(int topicId) async {
    await removeWatchedTopicId(topicId);
    // ★ コメントキャッシュも消さないと、一覧で「既読（青背景）」が消えない
    await CacheService.clear('comments_$topicId');

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

  void _startBackgroundMetaUpdate() {
    if (_metaUpdating) {
      debugPrint('⏭️ [Favorites] meta update already running');
      return;
    }

    _metaUpdating = true;
    historyUpdatingNotifier.value = true; // ★ 回転開始

    _runMetaUpdateLoop().whenComplete(() {
      _metaUpdating = false;
      historyUpdatingNotifier.value = false; // ★ 回転終了
    });
  }

  Future<void> _runMetaUpdateLoop() async {
    debugPrint('🚀 [Favorites] meta update loop start');

    // スナップショットを取っておく（途中で _watchedTopics が変わっても安全に処理できる）
    final topics = List<Map<String, dynamic>>.from(_watchedTopics);
    final now = DateTime.now();

    for (final t in topics) {
      if (!mounted) break;

      final id = t['id'] as int?;
      if (id == null) continue;

      // dat落ちチェック: posted_at が 1ヶ月より前ならスキップ
      final postedAtStr = (t['posted_at'] as String? ?? '').trim();

      // ★ GirlsChannel専用パーサで解釈
      final postedAt = postedAtStr.isEmpty
          ? null
          : parseGirlsChanPostedAt(postedAtStr);

      // postedAt が null → よく分からない → 「最近」とみなして fetch 続行
      // postedAt があって 31日より前 → dat落ち扱いでスキップ
      if (postedAt != null) {
        final diffDays = now.difference(postedAt).inDays;
        if (diffDays > 31) {
          debugPrint('⏭️ [Favorites] skip id=$id (dat落ち: $diffDays days, postedAt="$postedAtStr")');
          continue;
        }
      }

      final beforeComments = (t['comments'] as int?) ?? 0;

      try {
        // ★ 現在チェック中のトピック名を表示（トーストだと邪魔かもしれないので、一旦ログか、あるいは「チェック中...」みたいなのを出す？）
        // ユーザー要望: 「トースト、現在取得中のトピック名を出してほしい」
        final currentTitle = t['title'] as String? ?? 'トピック';
        if (mounted) {
          AppToast.show(context, '「$currentTitle」をチェック中...');
        }

        debugPrint('📡 [Favorites] fetch meta for id=$id');
        final meta = await fetchTopicMeta(id);
        debugPrint('📡 [Favorites] meta result for id=$id: $meta');
        final hasNew = await updateWatchedTopicFromMeta(meta);
        debugPrint('📡 [Favorites] hasNew for id=$id: $hasNew');

        if (hasNew && mounted) {
          final afterComments = (meta['total'] as int?) ?? beforeComments;
          final title = (meta['title'] as String?) ?? 'トピック';
          final topicId = id!;
          final postedAtStr = meta['posted_at'] as String? ?? '';

          // ★ UI上のコメント数を即座に更新
          setState(() {
            final index = _watchedTopics.indexWhere((wt) => wt['id'] == topicId);
            if (index >= 0) {
              _watchedTopics[index]['comments'] = afterComments;
              _watchedTopics[index]['title'] = title;
              _watchedTopics[index]['posted_at'] = postedAtStr;
            }
          });

          debugPrint('🚨 [Favorites] showing toast for id=$topicId: beforeComments=$beforeComments, afterComments=$afterComments, title="$title"');

          AppToast.show(
            context,
            '「$title」に新着 ($beforeComments → $afterComments)',
            onTap: () {
              debugPrint('👉 [Favorites] toast tapped for id=$topicId');
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => TopicDetailScreen(
                    topicId: topicId,
                    title: title,
                    commentCount: afterComments,
                    posted_at: postedAtStr,
                  ),
                ),
              );
            },
          );
        } else {
          // ★ 更新がない場合も表示
          if (mounted) {
            AppToast.show(context, '「$currentTitle」は新着なし');
          }
          debugPrint('🚨 [Favorites] NOT showing toast for id=$id: hasNew=$hasNew, mounted=$mounted');
        }
    } catch (e, st) {
      debugPrint('❌ [Favorites] meta update error id=$id: $e\n$st');
    }

      // ガルちゃん側へのスクレイプ負荷を抑えるためにウェイト
      await Future.delayed(const Duration(seconds: 5));
    }

    // 全件終わったら、更新されたコメント数・thumb・posted_at を反映するためもう一度読み直す
    if (mounted) {
      await _loadWatchedTopics();
    }

    debugPrint('🏁 [Favorites] meta update loop end');
  }




  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(child: AppSpinner(size: 20));
    } else if (_watchedTopics.isEmpty) {
      body = Center(
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
    } else {
      body = Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshWatched,
              child: CupertinoScrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: _watchedTopics.length,
                  itemBuilder: (context, i) {
                    final topic = _watchedTopics[i];
                    return TopicTile(
                      topic: topic,
                      controller: _controller,
                      showThumb: false,
                      showRemoveButton: true,
                      removeButtonAlwaysVisible: true,
                      onRemove: (id) async {
                        await _removeFromWatch(id);
                      },
                      onAfterPop: _onDetailReturned,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ★ どのパスでも必ず Scaffold を返す
    return Scaffold(
      body: body,
    );
  }
}

