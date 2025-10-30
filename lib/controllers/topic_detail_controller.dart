import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  // ==== persist scroll（新方式） ====
  Future<void> saveScrollByIndexAndFraction(int index, double fraction) async {
    if (_allComments.isEmpty) return;
    final safe = index.clamp(0, _allComments.length - 1);
    final no = (_allComments[safe]['no'] as int?) ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    await prefs.setInt('scroll_$topicId', no);
    await prefs.setDouble('scroll_frac_$topicId', f);
    _savedCommentNo = no;
    savedLocalFraction = f;
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
    _clippedNos = clips.where((c) => c['topicId'] == topicId).map<int>((c) => c['no'] as int).toSet();

    if (!_isWatched) {
      await addWatchedTopicId(topicId, title: title, comments: commentCount, posted_at: postedAt);
      _isWatched = true;
    }

    // キャッシュ
    final cacheKey = 'comments_$topicId';
    final cached = await CacheService.loadList(cacheKey);
    if (cached.isNotEmpty) {
      final locals = await _loadLocalComments();
      _allComments = [...cached, ...locals];
      _totalComments = cached.length;
      _rebuildIndexByNo();
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

      _loading = false;
      notifyListeners();
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
    try {
      final from = _lastRemoteNo > 0 ? _lastRemoteNo : lastRemoteNo;
      final fetched = await fetchCommentsWithPagination(topicId, offset: from, limit: commentsPerPage);
      final List<dynamic> fetchedList = (fetched['comments'] as List<dynamic>? ?? const []);
      // ignore: avoid_print
      print('[delta] from=$from -> fetched=${fetchedList.length}');
      if (fetchedList.isEmpty) return 0;

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
      if (newOnes.isEmpty) return 0;

      // 末尾に追加
      _allComments.addAll(newOnes);
      _rebuildIndexByNo();
      // インデックスと lastRemoteNo を更新
      for (int i = 0; i < newOnes.length; i++) {
        final no = newOnes[i]['no'] as int;
        _byNo[no] = _allComments.length - newOnes.length + i;
        if (no > _lastRemoteNo) _lastRemoteNo = no;
      }

      notifyListeners();
      return newOnes.length;
    } finally {
      _fetching = false;
    }
  }
  // --- コメント配列を更新したときに no->index を再構築 ---
  void _rebuildIndexByNo() {
    _indexByNo
      ..clear()
      ..addEntries(_allComments.asMap().entries.map((e) {
        final no = (e.value['no'] as int?) ?? -1;
        return MapEntry(no, e.key);
      }));
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

}
