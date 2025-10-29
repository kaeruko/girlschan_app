import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/cache_service.dart';
// 既存の watch/clip ユーティリティを import
import '../utils/log.dart';

class TopicDetailController extends ChangeNotifier {
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
  int get savedSyncedCount => _savedSyncedCount;
  DateTime? get lastSync => _lastSync;

  int serverSyncedCount() => _allComments.where((c) => c['isLocal'] != true).length;

  // ==== persist scroll ====
  Future<void> loadScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    _savedCommentNo = prefs.getInt('scroll_$topicId') ?? 0;
    _savedSyncedCount = prefs.getInt('synced_$topicId') ?? 0;
    logd('📖 loadScroll: no=$_savedCommentNo synced=$_savedSyncedCount');
  }

  Future<void> saveScrollByIndex(int index) async {
    if (_allComments.isEmpty) return;
    final safeIndex = index.clamp(0, _allComments.length - 1);
    final no = (_allComments[safeIndex]['no'] as int?) ?? 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('scroll_$topicId', no);
    await prefs.setInt('synced_$topicId', serverSyncedCount());
  }

  // ==== init ====
  Future<void> init() async {
    if (testingBypassInit) {
      _allComments = (testingInitialComments ?? const []).map((e) => Map<String, dynamic>.from(e)).toList();
      _totalComments = _allComments.length;
      _loading = false;
      notifyListeners();
      return;
    }

    await loadScrollPosition();

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
      await CacheService.saveList('comments_$topicId', _allComments);

      final locals = await _loadLocalComments();
      _allComments = [..._allComments, ...locals];

      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      notifyListeners();
      logd('API Error: $e');
    }
  }

  Future<void> fetchDelta({int? overrideOffset}) async {
    if (_loadingMore) return;
    _loadingMore = true;
    notifyListeners();

    try {
      final offset = overrideOffset ?? lastRemoteNo; // ← 最大noベース（OK）
      final page = await fetchCommentsWithPagination(topicId, offset: offset, limit: commentsPerPage);
      final newComments = (page['comments'] as List<dynamic>? ?? []);

      final total = (page['total'] as int?) ?? _totalComments;
      final existingRemote = _allComments.where((c) => c['isLocal'] != true).toList();
      final mergedRemote = _merge(existingRemote, newComments);
      final locals = _allComments.where((c) => c['isLocal'] == true).toList();

      _totalComments = total;
      _allComments = [...mergedRemote, ...locals];
      _lastSync = DateTime.now();

      await CacheService.saveList('comments_$topicId', mergedRemote);
    } catch (e) {
      logd('❌ delta error: $e');
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
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

  List<dynamic> _merge(List<dynamic> existing, List<dynamic> add) {
    final m = <int, dynamic>{};
    for (final c in existing) {
      final no = c['no'] as int?;
      if (no != null) m[no] = c;
    }
    for (final c in add) {
      final no = c['no'] as int?;
      if (no != null) m[no] = c;
    }
    final out = m.values.toList();
    out.sort((a, b) => ((a['no'] as int?) ?? 0).compareTo((b['no'] as int?) ?? 0));
    return out;
  }
}
