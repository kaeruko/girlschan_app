import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/log.dart';
import '../utils/platform_helper.dart'; // ★追加
import '../widgets/topic_tile.dart';
import '../widgets/topic_tile_controller.dart';
import '../widgets/common/app_spinner.dart';
import '../widgets/common/app_toast.dart';

class TopicListScreen extends StatefulWidget {
  /// 'new' または 'popular' - どのトピックを表示するか
  final String sortOrder;

  /// トピックタップ時のコールバック（3ペイン構成用）
  final Function(int topicId, String title, int comments, String postedAt)? onTopicTap;

  /// 新規タブで開くコールバック（Cmd+クリック / 中クリック）
  final Function(int topicId, String title, int comments, String postedAt)? onTopicNewTabTap;

  const TopicListScreen({
    super.key,
    this.sortOrder = 'popular',
    this.onTopicTap,
    this.onTopicNewTabTap,
  });

  @override
  State<TopicListScreen> createState() => TopicListScreenState();
}



class TopicListScreenState extends State<TopicListScreen>
  with WidgetsBindingObserver {
  late final String cacheKey;

  final _controller = TopicTileController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;
  bool _fetching = false; // ⭐ 多重実行防止フラグ

  // 広告関連
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // sortOrder に応じてキャッシュキーを切り替える
    cacheKey = widget.sortOrder == 'new' ? 'topics_new' : 'topics_popular';
    // logd('🔧 [initState] sortOrder=${widget.sortOrder}, cacheKey=$cacheKey', name: 'TopicList');
    _loadFromCache();
    _loadBannerAd();
  }

  Future<void> _onAfterPopFromTile(int idx, int id) async {
    logd('🔔 [TopicList] onAfterPop received index=$idx id=$id', name: 'TopicList');

    await _updateTopicInList(idx, id);

    
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
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

  void refreshTiles() {
    _controller.refreshAll();
  }

  Future<void> reload() async {
    await fetchFromServer();
  }

  Future<void> _updateTopicInList(int index, int topicId) async {
    
    logd('🔄 [_updateTopicInList] Start processing index=$index, id=$topicId', name: 'TopicList');

    try {
      // final metaKey = 'topic_meta_$topicId';
      // final meta = await CacheService.loadMap(metaKey);
      final meta = await getTopicMetaFromDb(topicId);
      
      if (!mounted) {
        
        return;
      }

      setState(() {
        // 1. 安全のためリストを複製（再描画を確実にトリガーするため）
        final List<Map<String, dynamic>> newList = List.from(_topics);

        // 2. インデックスがずれていないか確認＆修正
        int currentIdx = index;
        if (currentIdx < 0 || currentIdx >= newList.length || newList[currentIdx]['id'] != topicId) {
           currentIdx = newList.indexWhere((t) => t['id'] == topicId);
        }
        if (currentIdx == -1) {
          
          return; // 見つからなければ終了
        }

        // 3. 対象トピックを取得（削除はしない）
        final targetTopic = newList[currentIdx];

        // 4. 情報を最新化する
        final updatedTopic = {
          ...targetTopic,
          if (meta != null && meta['total'] != null) 'comments': meta['total'],
          if (meta != null && meta['posted_at'] != null) 'posted_at': meta['posted_at'],
          if (meta != null && meta['thumb'] != null) 'thumb': meta['thumb'],
        };

        // 5. 元の位置で更新する（移動させない）
        newList[currentIdx] = updatedTopic;
        
        // 6. 画面用リストを差し替え
        _topics = newList;
        
        logd('✅ [_updateTopicInList] Updated in place: ${updatedTopic['title']}', name: 'TopicList');
      });
      
      // 7. タイルコントローラーのリフレッシュ（重要）
      await _controller.refreshAll();
      

    } catch (e, st) {
      
      logd('❌ [_updateTopicInList] Error: $e', name: 'TopicList');
    }
  }

  Future<void> _loadFromCache() async {
    // logd(' [_loadFromCache] Loading topics from cache... (sortOrder=${widget.sortOrder}, cacheKey=$cacheKey)', name: 'TopicList');

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
    if (mounted) setState(() => _fetching = true); // スピナーを即時表示

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
      
      //  watchedTopicsのコメント数を更新
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
        // ★ 修正: 既にデータがある場合はキャッシュで上書きしない
        if (_topics.isEmpty && cached.isNotEmpty) {
          _topics = cached.cast<Map<String, dynamic>>();
          logd('❌ [fetchFromServer] エラー時にキャッシュから${_topics.length}件読み込み', name: 'TopicList');
        } else {
             logd('❌ [fetchFromServer] エラー発生。既存データがあるためキャッシュ復元はスキップ', name: 'TopicList');
        }
        _loading = false;
      });
      await _controller.refreshAll();

      if (mounted) {
        await AppToast.show(context, 'データの更新に失敗しました（キャッシュを使用）');
      }
    } finally {
      if (mounted) setState(() => _fetching = false); // ⭐ ロック解除 + UI更新
    }
  }

  Future<void> _removeCommentsCache(int topicId) async {
    logd('🗑️ [TopicList] _removeCommentsCache called: ID=$topicId', name: 'TopicList');
    // ★ watched_topics_full からも削除（履歴に残らないようにする）
    await removeWatchedTopicId(topicId);
    await deleteTopicComments(topicId);
    
    // ★ リストからは削除しない（履歴のみ消す）
    /*
    if (mounted) {
      setState(() {
        _topics.removeWhere((t) => t['id'] == topicId);
      });
    }
    */
    
    await _controller.refreshAll();
    logd('🗑️ [TopicList] Topic removed from list', name: 'TopicList');
  }

  void _loadBannerAd() {
    // デスクトップなどは広告非対応のためスキップ
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-1701253412237513/7949216085',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isAdLoaded = true;
          });
          logd('✅ [TopicList] 広告読み込み成功');
        },
        onAdFailedToLoad: (ad, error) {
          logd('❌ [TopicList] 広告読み込み失敗: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      throw StateError('TopicList ScrollController is not attached.');
    }
    await _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Widget _buildScrollToTopButton() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.18),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(38, 38),
        borderRadius: BorderRadius.circular(19),
        onPressed: _scrollToTop,
        child: Icon(
          CupertinoIcons.arrow_up,
          size: 20,
          color: CupertinoColors.label.resolveFrom(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: const Center(child: AppSpinner(size: 32, showLabel: true)),
      );
    }

    // logd('🎨 [TopicList.build] UI描画: ${_topics.length}件のトピック表示 (sortOrder=${widget.sortOrder}, cacheKey=$cacheKey)', name: 'TopicList');

    return Scaffold(
      appBar: PlatformHelper.isDesktop ? AppBar(
        title: Text(widget.sortOrder == 'new' ? '新着トピック' : '人気トピック', style: const TextStyle(fontSize: 16)),
        actions: [
          if (_fetching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: AppSpinner(size: 18)),
            )
          else
            IconButton(
              icon: const Icon(CupertinoIcons.refresh),
              tooltip: '更新',
              onPressed: fetchFromServer,
            ),
          const SizedBox(width: 8),
        ],
        elevation: 1,
        backgroundColor: CupertinoColors.systemBackground,
        foregroundColor: CupertinoColors.label,
        toolbarHeight: 44, // コンパクトな高さ
      ) : null,
      body: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: fetchFromServer,
                        child: Scrollbar(
                          thumbVisibility: true, // ★ Macでは常にバーを表示
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
                              final id = topic['id'] as int;
                              final idx = index;
                              return TopicTile(
                                key: ValueKey<int>(id), // ★ これ必須
                                topic: topic,
                                controller: _controller,
                                showThumb: true,                      // 一覧はサムネ表示
                                onRemove: _removeCommentsCache,        // ×でコメントキャッシュ削除
                                onAfterPop: () => _onAfterPopFromTile(idx, id),
                                onTopicTap: widget.onTopicTap,
                                onTopicNewTabTap: widget.onTopicNewTabTap,
                              );
                            },
                          ),
                        ),
                      ),
                      if (widget.sortOrder == 'new')
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Center(child: _buildScrollToTopButton()),
                        ),
                    ],
                  ),
                ),
                // 広告バナー表示
                if (_isAdLoaded && _bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
              ],
            ),
    );
  }
}
