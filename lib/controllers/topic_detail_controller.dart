
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../models/comment.dart';
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
        comments.indexWhere((e) => e.id == no) >= 0) {
      return;
    }
    // 無限ループ防止で上限を決める
    const int maxRounds = 8;
    for (int r = 0; r < maxRounds; r++) {
      final added = await fetchDelta();
      if (added <= 0) break;
      if (indexByNo[no] != null ||
          comments.indexWhere((e) => e.id == no) >= 0) {
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
    this.saveReadPosition = true, // ★ 追加
  });

  final int topicId;
  final String title;
  final int commentCount;
  final String postedAt;

  final bool enableRefresh;
  final bool saveReadPosition; // ★ 追加

  // state
  static const int commentsPerPage = 500;

  bool _hasMore = true;   // まだ続きを取れるか
  bool get hasMore => _hasMore;

  List<Comment> _allComments = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _isWatched = false;
  int _totalComments = 0;
  final Map<int, int> _clipStatusMap = {}; // commentNo -> labelId
  DateTime? _lastSync;

  int _savedCommentNo = 0;
  int _savedSyncedCount = 0;

  bool _hasDraft = false;
  bool get hasDraft => _hasDraft;
  
  int? _myCommentLabelId; // "My Comments" label ID cache

  // getters
  List<Comment> get comments => _allComments;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get isWatched => _isWatched;
  int get totalComments => _totalComments;
  int? get myCommentLabelId => _myCommentLabelId; // ★ 公開
  int get savedCommentNo => _savedCommentNo;
  set savedCommentNo(int value) => _savedCommentNo = value;
  int get savedSyncedCount => _savedSyncedCount;
  DateTime? get lastSync => _lastSync;

  int serverSyncedCount() => _allComments.where((c) => !c.isLocal).length;

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
    // ★ saveReadPosition が false なら保存しない
    if (!saveReadPosition) return;

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
      final no = _allComments[safe].id;

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
    // ★ saveReadPosition が false なら保存しない
    if (!saveReadPosition) return;

    _saveDebounce?.cancel();
    final i = _pendingIndex;
    final f = _pendingFraction;
    _pendingIndex = null;
    _pendingFraction = null;
    if (i == null || f == null) return;

    if (_allComments.isEmpty) return;
    final safe = i.clamp(0, _allComments.length - 1);
    final no = _allComments[safe].id;

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

  /// 下書きがあるかチェック
  Future<void> checkDraft() async {
    final exists = await CacheService.hasDraft(topicId);
    if (_hasDraft != exists) {
      _hasDraft = exists;
      notifyListeners();
    }
  }

  // ==== init ====
  Future<void> init() async {
    await checkDraft();
    await _loadSavedScroll();
    logd('[init] after _loadSavedScroll: savedCommentNo=$_savedCommentNo, savedLocalFraction=$savedLocalFraction');

    // 履歴・クリップ
    final watched = await getWatchedTopicIds();
    final clips = await getClippedComments();
    _isWatched = watched.contains(topicId);
    
    // ★ クリップされたコメントのラベルIDをマップに保存
    _clipStatusMap.clear();
    for (final clip in clips.where((c) => c['topicId'] == topicId)) {
      final no = clip['no'] as int;
      final labelId = clip['labelId'] as int? ?? 0;
      _clipStatusMap[no] = labelId;
    }
    
    // ★ "My Comments" label ID をキャッシュ
    _myCommentLabelId = await getOrCreateMyCommentLabel();

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
    _allComments = [
      ...cached.map((e) => Comment.fromJson(e as Map<String, dynamic>)),
      ...locals
    ];
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
      final page = await fetchCommentsWithPagination(topicId, offset: 0, limit: commentsPerPage, old: _isOld);
      final rawList = (page['comments'] as List<dynamic>? ?? []);
      final list = rawList.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
      final total = (page['total'] as int?) ?? list.length;

      _allComments = list;
      _totalComments = total;
      _hasMore = list.length == commentsPerPage;

      await CacheService.saveList('comments_$topicId', _allComments.map((c) => c.toJson()).toList());

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

  DateTime? _lastFetchTime;

  Future<int> fetchDelta() async {
    if (_fetching) return 0;

    // ★ 短時間の連打防止（1秒間隔）
    final now = DateTime.now();
    if (_lastFetchTime != null && now.difference(_lastFetchTime!).inMilliseconds < 1000) {
      return 0;
    }
    _lastFetchTime = now;

    _fetching = true;
    _loadingMore = true;
    notifyListeners(); // ★ ローディング開始を UI に通知
    
    try {
      final from = _lastRemoteNo > 0 ? _lastRemoteNo : lastRemoteNo;
      final fetched = await fetchCommentsWithPagination(topicId, offset: from, limit: commentsPerPage, old: _isOld);
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
      final List<Comment> newOnes = [];
      for (final c in fetchedList) {
        final map = c as Map<String, dynamic>;
        final no = (map['no'] as int?) ?? 0;
        if (no <= 0) continue;
        if (_byNo.containsKey(no)) continue;
        newOnes.add(Comment.fromJson(map));
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
        final no = newOnes[i].id;
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
      await CacheService.saveList('comments_$topicId', _allComments.map((c) => c.toJson()).toList());
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

  /// キャッシュとスクロール位置を破棄して最新500件を取り直す
  Future<void> hardReload() async {
    if (_loading || _fetching) return;
    _loading = true;
    notifyListeners();

    try {
      // 1. メモリ上のデータをクリア
      _allComments = [];
      _indexByNo.clear();
      _byNo.clear();
      _totalComments = 0;
      _lastRemoteNo = 0;
      _hasMore = false;

      // 2. SharedPreferences (スクロール位置) をクリア
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('scroll_$topicId');
      await prefs.remove('scroll_frac_$topicId');
      _savedCommentNo = 0;
      savedLocalFraction = 0.0;

      // 3. キャッシュをクリア
      await CacheService.saveList('comments_$topicId', []);
      const reloadLimit = 500;
      final page = await fetchCommentsWithPagination(topicId, offset: 0, limit: reloadLimit, old: _isOld);
      final rawList = (page['comments'] as List<dynamic>? ?? []);
      final list = rawList.map((e) => Comment.fromJson(e as Map<String, dynamic>)).toList();
      final total = (page['total'] as int?) ?? list.length;

      _allComments = list;
      _totalComments = total;
      _hasMore = list.length >= reloadLimit; // 500件取れたらまだあるかも

      // 5. 再構築
      _rebuildIndexByNo();
      
      // インデックスと lastRemoteNo を更新
      for (int i = 0; i < list.length; i++) {
        final no = list[i].id;
        _byNo[no] = i; // indexByNo と重複するが _byNo は fetchDelta 用
        if (no > _lastRemoteNo) _lastRemoteNo = no;
      }

      // 6. 新しいデータをキャッシュ保存
      await CacheService.saveList('comments_$topicId', _allComments.map((c) => c.toJson()).toList());
      
      // 7. 履歴も更新
      await updateWatchedTopicsComments([
        {'id': topicId, 'comments': _totalComments}
      ]);

      _freezeSaving();
    } catch (e) {
      logd('Hard Reload Error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // --- コメント配列を更新したときに no->index を再構築 ---
  void _rebuildIndexByNo() {
    _indexByNo.clear();
    _byNo.clear();                 // ★ 初回ページも含めて dedupe 用に埋め直す

    for (int i = 0; i < _allComments.length; i++) {
      final no = _allComments[i].id;
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
      if (c.isLocal) continue;
      final n = c.id;
      if (n > mx) mx = n;
    }
    return mx;
  }

  // ==== clips ====
  Future<void> toggleClip(Comment comment, {int labelId = 0}) async {
    final no = comment.id;
    if (_clipStatusMap.containsKey(no)) {
      await removeClippedComment(topicId, no);
      _clipStatusMap.remove(no);
    } else {
      await addClippedComment(
        topicId: topicId,
        topicTitle: title,
        commentNo: no,
        commentBody: comment.body,
        posted_at: comment.postedAt,
        name: comment.name,
        plus: comment.plus,
        minus: comment.minus,
        anchors: comment.anchors,
        reverse_anchors: comment.reverseAnchors,
        labelId: labelId,
      );
      _clipStatusMap[no] = labelId;
    }
    notifyListeners();
  }

  bool isClipped(int no) => _clipStatusMap.containsKey(no);

  CommentUserStatus getUserStatus(int no) {
    if (!_clipStatusMap.containsKey(no)) return CommentUserStatus.none;
    final labelId = _clipStatusMap[no]!;
    if (_myCommentLabelId != null && labelId == _myCommentLabelId) {
      return CommentUserStatus.myComment;
    }
    return CommentUserStatus.clipped;
  }

  Comment? getCommentByNo(int no) {
    try {
      return _allComments.firstWhere((c) => c.id == no);
    } catch (_) {
      return null;
    }
  }

  // ==== locals ====
  Future<List<Comment>> _loadLocalComments() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'local_comments_$topicId';
    final stored = prefs.getStringList(key) ?? [];
    final list = <Comment>[];
    for (final e in stored) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        m['isLocal'] = true;
        list.add(Comment.fromJson(m));
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
      
      // ★ comments が 0 の場合は、既存の値を維持する（上書きしない）
      if (comments > 0) {
        watched['comments'] = comments;
      } else {
        // 既存の値があればそれをキープ、なければ 0 のまま
      }

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

  bool get _isOld {
    if (postedAt.isEmpty) return false;
    final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(postedAt);
    if (m == null) return false;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final date = DateTime(y, mo, d);
    final diff = DateTime.now().difference(date).inDays;
    logd('📅 [isOld] postedAt=$postedAt diff=$diff days (threshold=30) -> isOld=${diff > 30}');
    return diff > 30;
  }
}
