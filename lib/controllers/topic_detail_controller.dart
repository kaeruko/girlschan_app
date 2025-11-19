
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/cache_service.dart';
// 既存の watch/clip ユーティリティを import
import '../utils/log.dart';


class TopicDetailController extends ChangeNotifier {
  double savedLocalFraction = 0.0;  // そのアイテム内の位置（0.0〜1.0）

  // no -> index の逆引き（UIが高速に anchorIndex を求めるため）
  final Map<int, int> _indexByNo = {};
  Map<int, int> get indexByNo => _indexByNo;

  // コメント番号 -> GlobalKey のマッピング（復元時に使用）
  final Map<int, GlobalKey> commentKeys = {};
  
  /// コメント番号に対応する GlobalKey を取得（なければ新規作成）
  GlobalKey keyForCommentNo(int no) => commentKeys.putIfAbsent(no, () => GlobalKey(debugLabel: 'comment_$no'));

  // ---- 保存凍結とデバウンス ----
  DateTime _mutatingUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _saveDebounce;
  int? _pendingIndex;
  double? _pendingFraction;

  void _freezeSaving([Duration d = const Duration(milliseconds: 350)]) {
    final now = DateTime.now();
    _mutatingUntil = now.add(d);
  }

  bool get _savingFrozen => DateTime.now().isBefore(_mutatingUntil);

  /// 指定Noが入るまで差分取得を繰り返す（最大8回）
  Future<void> ensureContainsNo(int no) async {
    // すでに入っていれば何もしない
    if (indexByNo[no] != null ||
        comments.indexWhere((e) => (e['no'] as int?) == no) >= 0) {
      return;
    }
    // 無限ループ防止で上限を決める
    const int maxRounds = 8;
    for (int r = 0; r < maxRounds; r++) {
      final added = await fetchDelta();
      if (added <= 0) break;
      if (indexByNo[no] != null ||
          comments.indexWhere((e) => (e['no'] as int?) == no) >= 0) {
        break;
      }
    }
    notifyListeners();
  }

  // 可変高さメジャーを UI から参照できるよう公開（_measが存在する場合）
  // VariableListMeasurer get measurer => _meas;
  TopicDetailController({
    required this.topicId,
    required this.title,
    required this.commentCount,
    required this.postedAt,
    this.enableRefresh = true,
    this.testingBypassInit = false,
    this.testingInitialComments,
  });

  final int topicId;
  final String title;
  final int commentCount;
  final String postedAt;

  final bool enableRefresh;
  final bool testingBypassInit;
  final List<Map<String, dynamic>>? testingInitialComments;

  // state
  static const int commentsPerPage = 500;

  bool _hasMore = true;   // まだ続きを取れるか
  bool get hasMore => _hasMore;

  List<dynamic> _allComments = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _isWatched = false;
  int _totalComments = 0;
  Set<int> _clippedNos = {};
  DateTime? _lastSync;

  int _savedCommentNo = 0;
  int _savedSyncedCount = 0;

  // getters
  List<dynamic> get comments => _allComments;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get isWatched => _isWatched;
  int get totalComments => _totalComments;
  Set<int> get clippedNos => _clippedNos;
  int get savedCommentNo => _savedCommentNo;
  set savedCommentNo(int value) => _savedCommentNo = value;
  int get savedSyncedCount => _savedSyncedCount;
  DateTime? get lastSync => _lastSync;

  int serverSyncedCount() => _allComments.where((c) => c['isLocal'] != true).length;

  // 既存のローカルキー関数（君の方針に合わせて）:
  String _kScrollNo(int id)   => 'scroll_$id';
  String _kScrollFrac(int id) => 'scroll_frac_$id';

  // ★ 追加：フラクションだけ消す
  Future<void> clearScrollFractionOnly() async {
    savedLocalFraction = 0.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kScrollFrac(topicId));
  }

  // ==== persist scroll（新方式：凍結＋デバウンス付き） ====
  Future<void> saveScrollByIndexAndFraction(int index, double fraction) async {
    // 最新候補を溜める（スクロール中の大量イベントを圧縮）
    _pendingIndex = index;
    _pendingFraction = fraction;

    // 既存の確定予約があれば取り消し
    _saveDebounce?.cancel();

    // 負の遅延を回避
    Duration extra = const Duration(milliseconds: 80);
    Duration base  = const Duration(milliseconds: 120);
    if (_savingFrozen) {
      final remain = _mutatingUntil.difference(DateTime.now());
      base = (remain.isNegative ? Duration.zero : remain) + extra;
    }

    // 予約
    _saveDebounce = Timer(base, () async {
      final i = _pendingIndex;
      final f = _pendingFraction;
      _pendingIndex = null;
      _pendingFraction = null;
      if (i == null || f == null) return;

      if (_allComments.isEmpty) return;
      final safe = i.clamp(0, _allComments.length - 1);
      final no = (_allComments[safe]['no'] as int?) ?? 0;

      final prefs = await SharedPreferences.getInstance();
      final ff = f.isFinite ? f.clamp(0.0, 1.0) : 0.0;
      await prefs.setInt('scroll_$topicId', no);
      await prefs.setDouble('scroll_frac_$topicId', ff);

      _savedCommentNo = no;
      savedLocalFraction = ff;

      // ★コミットログ（これで保存→復元の整合が追える）
      // logd('[saveScroll] topic=$topicId no=$no index=$safe frac=$ff');
    });

    // ★スケジュールログ（必要なら）
    // logd('[saveScroll] schedule idx=$index frac=$fraction '
    //      'delay=${base.inMilliseconds}ms frozen=$_savingFrozen');
  }

  // ★未確定分を即書き込むフラッシュ
  Future<void> flushPendingScrollSave() async {
    _saveDebounce?.cancel();
    final i = _pendingIndex;
    final f = _pendingFraction;
    _pendingIndex = null;
    _pendingFraction = null;
    if (i == null || f == null) return;

    if (_allComments.isEmpty) return;
    final safe = i.clamp(0, _allComments.length - 1);
    final no = (_allComments[safe]['no'] as int?) ?? 0;

    final prefs = await SharedPreferences.getInstance();
    final ff = f.isFinite ? f.clamp(0.0, 1.0) : 0.0;
    await prefs.setInt('scroll_$topicId', no);
    await prefs.setDouble('scroll_frac_$topicId', ff);

    _savedCommentNo = no;
    savedLocalFraction = ff;
    logd('[saveScroll:flush] topic=$topicId no=$no index=$safe frac=$ff');
  }

  Future<void> _loadSavedScroll() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedNo = prefs.getInt('scroll_$topicId') ?? 0;
    final loadedFrac = prefs.getDouble('scroll_frac_$topicId') ?? 0.0;
      logd('[loadSavedScroll] scroll_${topicId}=$loadedNo, scroll_frac_${topicId}=$loadedFrac');
    _savedCommentNo = loadedNo;
    savedLocalFraction = loadedFrac;
  }

  // ==== init ====
  Future<void> init() async {
    if (testingBypassInit) {
      _allComments = (testingInitialComments ?? const []).map((e) => Map<String, dynamic>.from(e)).toList();
      _totalComments = _allComments.length;
      _rebuildIndexByNo();
      _loading = false;
      notifyListeners();
      return;
    }

    await _loadSavedScroll();
    logd('[init] after _loadSavedScroll: savedCommentNo=$_savedCommentNo, savedLocalFraction=$savedLocalFraction');

    // 履歴・クリップ
    final watched = await getWatchedTopicIds();
    final clips = await getClippedComments();
    _isWatched = watched.contains(topicId);
    _clippedNos = clips
        .where((c) => c['topicId'] == topicId)
        .map<int>((c) => c['no'] as int)
        .toSet();

    // ★ ここで必ず watchedAt を「今」にする（新規でも既存でも）
    await _touchWatchedTopic(
      id: topicId,
      title: title,
      comments: commentCount,
      postedAt: postedAt,
    );
    _isWatched = true;

    // キャッシュ
    final cacheKey = 'comments_$topicId';
    final cached = await CacheService.loadList(cacheKey);
    if (cached.isNotEmpty) {
      final locals = await _loadLocalComments();
      _allComments = [...cached, ...locals];
      _totalComments = cached.length;
      _rebuildIndexByNo();
      _freezeSaving(); // ★ここを追加（レイアウト安定まで保存を遅延）
      _loading = false;
      notifyListeners();
      return;
    }

    // 初回取得
    await fetchFirstPage();
  }

  Future<void> fetchFirstPage() async {
    try {
      final page = await fetchCommentsWithPagination(topicId, offset: 0, limit: commentsPerPage);
      final list = (page['comments'] as List<dynamic>? ?? []).toList();
      final total = (page['total'] as int?) ?? list.length;

      _allComments = list;
      _totalComments = total;
      _hasMore = list.length == commentsPerPage;

      await CacheService.saveList('comments_$topicId', _allComments);

      final locals = await _loadLocalComments();
      _allComments = [..._allComments, ...locals];
      _rebuildIndexByNo();

      _freezeSaving();
      _loading = false;
      notifyListeners();

      // watchedTopicsのコメント数を更新
      await updateWatchedTopicsComments([
        {'id': topicId, 'comments': _totalComments}
      ]);
    } catch (e) {
      _loading = false;
      notifyListeners();
      logd('API Error: $e');
    }
  }

  bool _fetching = false;
  int _lastRemoteNo = 0;
  final Map<int, int> _byNo = {};

  Future<int> fetchDelta() async {
    if (_fetching) return 0;
    _fetching = true;
    _loadingMore = true;
    notifyListeners(); // ★ ローディング開始を UI に通知
    
    try {
      final from = _lastRemoteNo > 0 ? _lastRemoteNo : lastRemoteNo;
      final fetched = await fetchCommentsWithPagination(topicId, offset: from, limit: commentsPerPage);
      final List<dynamic> fetchedList = (fetched['comments'] as List<dynamic>? ?? const []);
      // 追加: サーバ側の総件数が返るなら拾う
      final fetchedTotal = (fetched['total'] as int?) ?? 0;
      
      // ignore: avoid_print
      print('[delta] from=$from -> fetched=${fetchedList.length}');
      if (fetchedList.isEmpty) {
        // 追加: 件数だけ更新されているケースでも UI を更新
        if (fetchedTotal > 0 && fetchedTotal != _totalComments) {
          _totalComments = fetchedTotal;
        }
        _loadingMore = false;
        notifyListeners();
        return 0;
      }

      // 重複排除
      final List<Map<String, dynamic>> newOnes = [];
      for (final c in fetchedList) {
        final no = (c['no'] as int?) ?? 0;
        if (no <= 0) continue;
        if (_byNo.containsKey(no)) continue;
        newOnes.add(Map<String, dynamic>.from(c));
      }
      // ignore: avoid_print
      print('[delta] added=${newOnes.length}');
      if (newOnes.isEmpty) {
        // 追加: 件数の更新
        if (fetchedTotal > 0 && fetchedTotal != _totalComments) {
          _totalComments = fetchedTotal;
        }
        _loadingMore = false;
        notifyListeners();
        return 0;
      }

      // 末尾に追加
      _allComments.addAll(newOnes);
      _rebuildIndexByNo();
      // インデックスと lastRemoteNo を更新
      for (int i = 0; i < newOnes.length; i++) {
        final no = newOnes[i]['no'] as int;
        _byNo[no] = _allComments.length - newOnes.length + i;
        if (no > _lastRemoteNo) _lastRemoteNo = no;
      }
      
      // 追加: 総件数の更新（API の total 優先、なければ最大Noでフォールバック）
      if (fetchedTotal > 0) {
        _totalComments = fetchedTotal;
      } else {
        // Girls Channelのように No が連番なら max(No) を総件数相当として扱える
        // _totalComments = lastRemoteNo;
      }
      
      // ★ 追加: キャッシュ保存
      await CacheService.saveList('comments_$topicId', _allComments);
      _freezeSaving();

      _loadingMore = false;
      notifyListeners();
      return newOnes.length;
    } finally {
      _fetching = false;
      _loadingMore = false;
      notifyListeners(); // ★ ローディング終了を UI に通知

      // watchedTopicsのコメント数を更新（通信後に必ず実行）
      await updateWatchedTopicsComments([
        {'id': topicId, 'comments': _totalComments}
      ]);
    }
  }
  // --- コメント配列を更新したときに no->index を再構築 ---
  void _rebuildIndexByNo() {
    _indexByNo.clear();
    _byNo.clear();                 // ★ 初回ページも含めて dedupe 用に埋め直す

    for (int i = 0; i < _allComments.length; i++) {
      final no = (_allComments[i]['no'] as int?) ?? -1;
      if (no <= 0) continue;
      _indexByNo[no] = i;
      _byNo[no] = i;               // ★ これが重要。fetchDelta の重複判定が効く
    }

    // ついでに lastRemoteNo も最新に合わせておくと安全
    _lastRemoteNo = lastRemoteNo;
  }

  /// 取得済みリモートコメントの最大noを返す（ローカル投稿は除外）
  int get lastRemoteNo {
    var mx = 0;
    for (final c in _allComments) {
      if (c['isLocal'] == true) continue;
      final n = (c['no'] as int?) ?? 0;
      if (n > mx) mx = n;
    }
    return mx;
  }

  // ==== clips ====
  Future<void> toggleClip(Map<String, dynamic> comment) async {
    final no = comment['no'] as int;
    if (_clippedNos.contains(no)) {
      await removeClippedComment(topicId, no);
      _clippedNos.remove(no);
    } else {
      await addClippedComment(
        topicId: topicId,
        topicTitle: title,
        commentNo: no,
        commentBody: comment['body'] ?? '',
        posted_at: comment['posted_at'] ?? '',
        plus: comment['plus'] ?? 0,
        minus: comment['minus'] ?? 0,
      );
      _clippedNos.add(no);
    }
    notifyListeners();
  }

  dynamic getCommentByNo(int no) {
    try {
      return _allComments.firstWhere((c) => c['no'] == no);
    } catch (_) {
      return {};
    }
  }

  // ==== locals ====
  Future<List<Map<String, dynamic>>> _loadLocalComments() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_comments_$topicId';
    final stored = prefs.getStringList(key) ?? [];
    final list = <Map<String, dynamic>>[];
    for (final e in stored) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        m['isLocal'] = true;
        list.add(m);
      } catch (_) {
        // 壊れたデータはスキップ
      }
    }
    return list;
  }

  @override
  void dispose() {
    flushPendingScrollSave(); // デバウンス中の未確定分を即コミット
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _touchWatchedTopic({
    required int id,
    required String title,
    required int comments,
    required String postedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('watched_topics_full') ?? [];

    final nowIso = DateTime.now().toIso8601String();

    // 既存エントリを探す
    final idx = jsonList.indexWhere((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m['id'] == id;
    });

    if (idx >= 0) {
      // 既に watched に登録済み → 上書き
      final watched = jsonDecode(jsonList[idx]) as Map<String, dynamic>;
      watched['title'] = title;
      watched['comments'] = comments;
      watched['posted_at'] = postedAt;
      watched['watchedAt'] = nowIso; // ★ 最終閲覧時刻を更新
      jsonList[idx] = jsonEncode(watched);
    } else {
      // 初登録
      final watched = <String, dynamic>{
        'id': id,
        'title': title,
        'comments': comments,
        'posted_at': postedAt,
        'watchedAt': nowIso,
      };
      jsonList.add(jsonEncode(watched));
    }

    await prefs.setStringList('watched_topics_full', jsonList);
  }

}
