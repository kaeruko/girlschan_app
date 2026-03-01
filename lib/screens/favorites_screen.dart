import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Scaffold削除に伴い、Icons等で必要なら残す
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../widgets/common/app_toast.dart';
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';
import '../screens/topic_detail.dart';
import '../utils/log.dart';
import '../services/history_notifier.dart';

class FavoritesScreen extends StatefulWidget {
  final Function(int topicId, String title, int comments, String postedAt)? onTopicTap;

  const FavoritesScreen({
    super.key,
    this.onTopicTap,
  });

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen>
    with WidgetsBindingObserver {
  final _controller = TopicTileController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _watchedTopics = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _inFlight = false;
  bool _metaUpdating = false;
  
  // ★ UI進捗表示用
  String _progressStatus = '';

  // 日付解析用正規表現（コンパイル済・最適化）
  static final _dateRegex = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2}).*?(\d{1,2}):(\d{2})');

  void reloadFromOutside() {
    _loadWatchedTopics();
  }

  DateTime? parseGirlsChanPostedAt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.contains('前')) return DateTime.now();

    final m = _dateRegex.firstMatch(s);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
      );
    }
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWatchedTopics();
    historyUpdateNotifier.addListener(_loadWatchedTopics);
  }

  @override
  void dispose() {
    historyUpdateNotifier.removeListener(_loadWatchedTopics);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ★ 戻ってきた時に自動リロードさせたい場合はコメントアウトを外す
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (state == AppLifecycleState.resumed) {
  //     _loadWatchedTopics();
  //   }
  // }

  Future<void> _loadWatchedTopics() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final topics = await getWatchedTopics();
      
      // ソート: 最終閲覧日時が新しい順
      topics.sort((a, b) {
        final timeA = DateTime.tryParse(a['watchedAt'] ?? '') ?? DateTime(0);
        final timeB = DateTime.tryParse(b['watchedAt'] ?? '') ?? DateTime(0);
        return timeB.compareTo(timeA);
      });

      if (!mounted) return;
      setState(() {
        _watchedTopics = topics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _refreshWatched() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    await _loadWatchedTopics();
    if (mounted) setState(() => _refreshing = false);

    _startBackgroundMetaUpdate();
  }

  Future<void> _removeFromWatch(int topicId) async {
    logd('🗑️ [FavoritesScreen] _removeFromWatch called: ID=$topicId', name: 'FavoritesScreen');
    await removeWatchedTopicId(topicId);
    // await CacheService.clear('comments_$topicId');
    await deleteTopicComments(topicId);

    if (!mounted) return;
    setState(() {
      _watchedTopics.removeWhere((t) => t['id'] == topicId);
    });
    // コントローラー側のキャッシュもクリア（もしあれば）
    // await _controller.refreshAll(); // 全リフレッシュは重いので不要かも
  }

  Future<void> _onDetailReturned() async {
    await _loadWatchedTopics();
    await _controller.refreshAll();
  }

  void _startBackgroundMetaUpdate() {
    if (_metaUpdating) return;

    _metaUpdating = true;
    // historyUpdatingNotifier.value = true; // 必要ならコメントアウト解除

    _runMetaUpdateLoop().whenComplete(() {
      _metaUpdating = false;
      // historyUpdatingNotifier.value = false;
    });
  }

  Future<void> _runMetaUpdateLoop() async {
    // リストのコピーを作成して安全にループ
    final topics = List<Map<String, dynamic>>.from(_watchedTopics);
    final total = topics.length;
    final now = DateTime.now();

    if (mounted) {
      setState(() {
        _progressStatus = '更新チェックを開始します...';
      });
    }

    for (int i = 0; i < total; i++) {
      if (!mounted) break;

      final t = topics[i];
      final id = t['id'] as int?;
      if (id == null) continue;

      // ★ 進捗状況を更新
      if (mounted) {
        setState(() {
          _progressStatus = 'チェック中: ${i + 1} / $total 件';
        });
      }

      try {
        // dat落ちチェック
        final postedAtStr = (t['posted_at'] as String? ?? '').trim();
        final postedAt = parseGirlsChanPostedAt(postedAtStr);
        if (postedAt != null) {
          if (now.difference(postedAt).inDays > 31) continue;
        }

        final beforeComments = (t['comments'] as int?) ?? 0;
        
        final meta = await fetchTopicMeta(id);
        final hasNew = await updateWatchedTopicFromMeta(meta);

        if (hasNew && mounted) {
          final afterComments = (meta['total'] as int?) ?? beforeComments;
          final title = (meta['title'] as String?) ?? 'トピック';
          final postedAtStr = meta['posted_at'] as String? ?? '';

          // リストデータを更新
          final index = _watchedTopics.indexWhere((wt) => wt['id'] == id);
          if (index >= 0) {
            setState(() {
              // 1. 古いデータをコピーして新しい Map を作る（新品の箱を用意）
              final newTopicData = Map<String, dynamic>.from(_watchedTopics[index]);
              
              // 2. 新しい Map のデータを書き換える
              newTopicData['comments'] = afterComments;
              newTopicData['title'] = title;
              newTopicData['posted_at'] = postedAtStr;

              // 3. リストの中身を、新しい Map にそっくり入れ替える
              _watchedTopics[index] = newTopicData;
            });
          }

          // タイル表示を更新
          await _controller.refreshTopic(id);

          // ★ 新着があった場合のみトースト通知（これは有益なので残す）
          AppToast.show(
            context,
            '「$title」に新着 ($beforeComments → $afterComments)',
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => TopicDetailScreen(
                    topicId: id,
                    title: title,
                    commentCount: afterComments,
                    postedAt: postedAtStr,
                  ),
                ),
              );
            },
          );
        }
      } catch (e) {
        // ignore
      }
      
      // サーバー負荷対策ウェイト
      await Future.delayed(const Duration(seconds: 5));
    }

    // ★ 完了処理
    if (mounted) {
      setState(() {
        _progressStatus = ''; // バーを消す
      });
      await _loadWatchedTopics(); // 念のため最終同期
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      // ★ ナビゲーションバーは TabSpec 側でタイトル管理するなら不要だが、
      // 単体で動作させるならあっても良い。今回はタブの一部として埋め込まれる前提で
      // Scaffold の body 相当部分を作るが、Cupertino統一のため PageScaffold を使用。
      // もしタブ側の AppBar と二重になる場合は navigationBar を削除してください。
      navigationBar: CupertinoNavigationBar(
        middle: const Text('履歴'),
        transitionBetweenRoutes: false, // エラー回避のため明示的に設定
      ),
      child: SafeArea(
        bottom: false, // タブバーと被らないように
        child: _loading
            ? const Center(child: AppSpinner(size: 20))
            : _watchedTopics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(CupertinoIcons.clock, size: 64, color: CupertinoColors.systemGrey),
                        const SizedBox(height: 16),
                        const Text('閲覧したトピックはありません',
                            style: TextStyle(fontSize: 16, color: CupertinoColors.systemGrey)),
                        const SizedBox(height: 8),
                        const Text('トピックを見るとここに履歴が残ります',
                            style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey)),
                        // 強制リロードボタン（デバッグ用や復帰用）
                        CupertinoButton(
                          child: const Text('再読み込み'),
                          onPressed: _refreshWatched,
                        ),
                      ],
                    ),
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ★ iOS風のリフレッシュコントロール
                      CupertinoSliverRefreshControl(onRefresh: _refreshWatched),
                      
                      // ★ 進捗バー
                      if (_progressStatus.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Container(
                            width: double.infinity,
                            color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CupertinoActivityIndicator(radius: 8),
                                const SizedBox(width: 8),
                                Text(
                                  _progressStatus,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.systemBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final topic = _watchedTopics[i];
                            return TopicTile(
                              // これでコメント数が増えた瞬間に「別物」として強制的に再描画される
                              key: ValueKey('${topic['id']}_${topic['comments']}'), 
                              topic: topic,
                              controller: _controller,
                              showThumb: false,
                              onRemove: (id) async {
                                logd('🗑️ [FavoritesScreen] onRemove callback invoked: ID=$id', name: 'FavoritesScreen');
                                await _removeFromWatch(id);
                              },
                              onAfterPop: _onDetailReturned,
                              onTopicTap: widget.onTopicTap,
                            );
                          },
                          childCount: _watchedTopics.length,
                        ),
                      ),
                      
                      // 下部余白（タブバーに隠れないように）
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
      ),
    );
  }
}