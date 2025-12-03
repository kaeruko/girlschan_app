import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/log.dart';
import '../database/database.dart';
// import 'cache_service.dart'; // Keep for list caching in UI if needed, but we try to move away

final apiBase = AppConfig.apiBase;
final db = AppDatabase(); // Singleton

// ========== ヘルパー関数（HTTP共通処理） ==========

/// GETリクエストを実行し、JSONをデコードして返す（共通化）
Future<dynamic> _fetchJson(
  Uri uri, {
  Map<String, String>? headers,
  Duration? timeout,
}) async {
  logd('📡 APIリクエスト: $uri');

  final response = await http.get(uri, headers: headers).timeout(
    timeout ?? const Duration(seconds: 60),
    onTimeout: () => throw Exception('タイムアウト: API応答がありません'),
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('API Error: ${response.statusCode}');
  }
}

/// GETリクエストを実行し、Mapを返す
Future<Map<String, dynamic>> _fetchMap(
  Uri uri, {
  Map<String, String>? headers,
  Duration? timeout,
}) async {
  final data = await _fetchJson(uri, headers: headers, timeout: timeout);
  return data as Map<String, dynamic>;
}

/// GETリクエストを実行し、Listを返す
Future<List<dynamic>> _fetchList(
  Uri uri, {
  Map<String, String>? headers,
  Duration? timeout,
}) async {
  final data = await _fetchJson(uri, headers: headers, timeout: timeout);
  return data as List<dynamic>;
}

// ========== コメント評価 ==========

Future<bool> rateComment(int topicId, String commentId, int value) async {
  try {
    logd('');
    logd('============================================');
    logd('⭐ [rateComment] API呼び出し開始');
    logd('============================================');
    logd('');
    
    final url = 'https://girlschannel.net/topics/post_value?value=$value&topic_id=$topicId&comment_id=$commentId';
    logd('⭐ [rateComment] Request URL: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'accept': 'application/json, text/plain, */*',
        'user-agent': 'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
      },
    );
    
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return true;
      try {
        final data = jsonDecode(response.body);
        return data['result'] == true;
      } catch (e) {
        return true;
      }
    }
    return false;
  } catch (e) {
    logd('⭐ [rateComment] ❌ Error: $e');
    return false;
  }
}

// ========== トピック関連 ==========

/// 検索クエリでトピックを検索
Future<Map<String, dynamic>> searchTopics({
  required String query,
  int page = 1,
  int count = 50,
  String? dateFilter,
}) async {
  try {
    final uri = Uri.parse('$apiBase/search').replace(
      queryParameters: {
        'q': query,
        'page': page.toString(),
        'count': count.toString(),
        if (dateFilter != null) 'date_filter': dateFilter,
      },
    );
    
    final data = await _fetchMap(uri);
    return data;
  } catch (e) {
    logd('🔍 [searchTopics] ❌ Error: $e');
    rethrow;
  }
}

// 1件分のメタ情報を取得する
Future<Map<String, dynamic>> fetchTopicMeta(int topicId) async {
  final url = Uri.parse('$apiBase/topics/meta');
  final payload = jsonEncode({
    'ids': [topicId],
    'offset': 0,
    'limit': 1,
  });

  logd('📡 [fetchTopicMeta] POST $url payload=$payload', name: 'API');

  final resp = await http
      .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      )
      .timeout(const Duration(seconds: 30));

  if (resp.statusCode != 200) {
    throw Exception('fetchTopicMeta failed: ${resp.statusCode}');
  }

  final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
  final topics = decoded['topics'] as List<dynamic>? ?? const [];
  if (topics.isEmpty) {
    throw Exception('fetchTopicMeta empty result for id=$topicId');
  }

  return topics.first as Map<String, dynamic>;
}

/// watched_topics_full の中の 1件だけを meta で更新し、
/// 「コメント数が増えていたら true」を返す
Future<bool> updateWatchedTopicFromMeta(Map<String, dynamic> meta) async {
  final topicId = meta['id'] as int;
  final newTotal = (meta['total'] as int?) ?? 0;
  final newThumb = meta['thumb'] as String?;
  final newPostedAt = meta['posted_at'] as String?;

  // DBの履歴を更新
  final topic = await (db.select(db.topics)..where((t) => t.id.equals(topicId))).getSingleOrNull();
  
  if (topic != null && topic.lastViewedAt != null) {
    final oldTotal = topic.commentCount;
    if (newTotal > oldTotal) {
      // 更新あり
      await (db.update(db.topics)..where((t) => t.id.equals(topicId))).write(
        TopicsCompanion(
          commentCount: drift.Value(newTotal),
          postedAt: newPostedAt != null ? drift.Value(newPostedAt) : drift.Value.absent(),
          thumbnail: newThumb != null ? drift.Value(newThumb) : drift.Value.absent(),
          fetchedAt: drift.Value(DateTime.now()),
        )
      );
      return true;
    }
  }
  return false;
}


// キャッシュ対応のトピック取得
Future<List<dynamic>> fetchNewTopicsWithCache() async {
  try {
    final uri = '$apiBase/topics/new';
    final data = await _fetchList(Uri.parse(uri));
    
    // DBに保存
    await _upsertTopicsFromApi(data);
    
    return data;
  } catch (e) {
    rethrow;
  }
}

/// キャッシュ対応の人気トピック取得
Future<List<dynamic>> fetchPopularTopicsWithCache() async {
  try {
    final uri = '$apiBase/topics/popular';
    final data = await _fetchList(Uri.parse(uri));
    
    // DBに保存
    await _upsertTopicsFromApi(data);
    
    return data;
  } catch (e) {
    rethrow;
  }
}

Future<void> _upsertTopicsFromApi(List<dynamic> list) async {
  final entries = list.map((json) {
    return TopicsCompanion.insert(
      id: drift.Value(json['id']),
      title: json['title'],
      commentCount: drift.Value(json['comments'] ?? 0),
      postedAt: drift.Value(json['posted_at']),
      thumbnail: drift.Value(json['thumb']),
      fetchedAt: drift.Value(DateTime.now()),
    );
  }).toList();
  await db.upsertTopics(entries);
}

// キャッシュ対応のコメント取得（ページング対応）
Future<Map<String, dynamic>> fetchCommentsWithPagination(
  int topicId, {
  int offset = 0,
  int limit = 10,
  bool old = false,
}) async {
  try {
    final queryParams = {
      'offset': offset.toString(),
      'limit': limit.toString(),
    };
    if (old) {
      queryParams['old'] = 'true';
    }

    final uri = Uri.parse('$apiBase/topic/$topicId').replace(
      queryParameters: queryParams,
    );
    
    final data = await _fetchMap(uri);
    
    final comments = data['comments'] as List<dynamic>? ?? [];
    final total = data['total'] as int? ?? comments.length;
    final posted_at = data['posted_at'] as String? ?? '';
    final thumb = data['thumb'] as String?;

    // DBにコメント保存
    final commentEntries = comments.map((c) {
      return CommentsCompanion.insert(
        topicId: topicId,
        number: c['no'],
        body: c['body'],
        name: drift.Value(c['name']),
        postedAt: drift.Value(c['posted_at']),
        plus: drift.Value(c['plus'] ?? 0),
        minus: drift.Value(c['minus'] ?? 0),
        imageUrl: drift.Value(c['image_url']),
        anchors: drift.Value(List<int>.from(c['anchors'] ?? [])),
        reverseAnchors: drift.Value(List<int>.from(c['reverse_anchors'] ?? [])),
      );
    }).toList();
    await db.upsertComments(commentEntries);

    // DBのトピックメタ情報を更新
    // タイトルが不明な場合は更新のみ試みる
    await (db.update(db.topics)..where((t) => t.id.equals(topicId))).write(
      TopicsCompanion(
        commentCount: drift.Value(total),
        postedAt: posted_at.isNotEmpty ? drift.Value(posted_at) : drift.Value.absent(),
        thumbnail: thumb != null ? drift.Value(thumb) : drift.Value.absent(),
        fetchedAt: drift.Value(DateTime.now()),
      )
    );
    
    return {
      'comments': comments,
      'total': total,
      'posted_at': posted_at,
      'thumb': thumb,
      'offset': offset,
      'limit': limit,
    };
  } catch (e) {
    rethrow;
  }
}

/// 指定されたコメントのスレッド（アンカー先・元など）を取得
Future<Map<String, dynamic>> fetchCommentThread(int topicId, int commentId) async {
  try {
    final uri = Uri.parse('$apiBase/comment/$topicId/$commentId');
    final data = await _fetchMap(uri);
    return data;
  } catch (e) {
    rethrow;
  }
}

// ========== 履歴関連（トピック履歴） ==========

Future<List<Map<String, dynamic>>> getWatchedTopics() async {
  final history = await db.getHistory();
  return history.map((t) => {
    'id': t.id,
    'title': t.title,
    'comments': t.commentCount,
    'posted_at': t.postedAt,
    'thumb': t.thumbnail,
    'watchedAt': t.lastViewedAt?.toIso8601String(),
  }).toList();
}

Future<List<int>> getWatchedTopicIds() async {
  final history = await db.getHistory();
  return history.map((t) => t.id).toList();
}

Future<void> addWatchedTopic({
  required int id,
  required String title,
  required int comments,
  required String posted_at,
}) async {
  // トピックを保存（または更新）
  await db.upsertTopics([TopicsCompanion.insert(
    id: drift.Value(id),
    title: title,
    commentCount: drift.Value(comments),
    postedAt: drift.Value(posted_at),
    fetchedAt: drift.Value(DateTime.now()),
  )]);
  
  // 閲覧済みにマーク
  await db.markTopicAsViewed(id);
}

Future<void> removeWatchedTopicId(int id) async {
  // 履歴フラグを下ろす（データはキャッシュとして残す）
  await (db.update(db.topics)..where((t) => t.id.equals(id))).write(
    const TopicsCompanion(lastViewedAt: drift.Value(null)),
  );
}

/// APIから取得したトピックリストで、watchedTopicsのコメント数を更新
Future<void> updateWatchedTopicsComments(
  List<Map<String, dynamic>> fetchedTopics,
) async {
  // DBの一括更新
  await _upsertTopicsFromApi(fetchedTopics);
}

/// トピックを閲覧したとして、watchedAt（最終閲覧日時）を現在時刻に更新する
Future<void> touchWatchedTopic(int topicId) async {
  await db.markTopicAsViewed(topicId);
}

/// 履歴全体を削除
Future<void> clearWatchedHistory() async {
  await db.topics.update().write(
    const TopicsCompanion(lastViewedAt: drift.Value(null)),
  );
}

// ========== クリップ関連（コメント保存） ==========

Future<List<Map<String, dynamic>>> getClippedComments() async {
  // クリップされたコメントと、そのトピック情報を結合して取得
  final query = db.select(db.comments).join([
    drift.innerJoin(db.topics, db.topics.id.equalsExp(db.comments.topicId))
  ]);
  query.where(db.comments.isClipped.equals(true));
  query.orderBy([drift.OrderingTerm.desc(db.comments.clippedAt)]);
  
  final result = await query.get();
  
  return result.map((row) {
    final comment = row.readTable(db.comments);
    final topic = row.readTable(db.topics);
    return {
      'topicId': topic.id,
      'topicTitle': topic.title,
      'no': comment.number,
      'body': comment.body,
      'posted_at': comment.postedAt,
      'name': comment.name,
      'plus': comment.plus,
      'minus': comment.minus,
      'anchors': comment.anchors,
      'reverse_anchors': comment.reverseAnchors,
      'image_url': comment.imageUrl,
      'clipDate': comment.clippedAt?.toIso8601String(),
      'labelId': comment.labelId,
      'memo': comment.clipMemo,
    };
  }).toList();
}

Future<void> addClippedComment({
  required int topicId,
  required String topicTitle,
  required int commentNo,
  required String commentBody,
  required String posted_at,
  required String name,
  required int plus,
  required int minus,
  List<dynamic> anchors = const [],
  List<dynamic> reverse_anchors = const [],
  String? imageUrl,
  List<dynamic> urls = const [], // DBには未対応だが引数は維持
  int labelId = 0,
}) async {
  // トピックが存在しない場合は作成
  final topicExists = await (db.select(db.topics)..where((t) => t.id.equals(topicId))).getSingleOrNull();
  if (topicExists == null) {
    await db.upsertTopics([TopicsCompanion.insert(
      id: drift.Value(topicId),
      title: topicTitle,
      postedAt: drift.Value(posted_at),
      fetchedAt: drift.Value(DateTime.now()),
    )]);
  }

  // コメントをUpsertしつつクリップ状態にする
  // 既存のコメントがある場合は、クリップ情報を更新
  await db.batch((batch) {
    batch.insert(
      db.comments,
      CommentsCompanion.insert(
        topicId: topicId,
        number: commentNo,
        body: commentBody,
        name: drift.Value(name),
        postedAt: drift.Value(posted_at),
        plus: drift.Value(plus),
        minus: drift.Value(minus),
        imageUrl: drift.Value(imageUrl),
        anchors: drift.Value(List<int>.from(anchors)),
        reverseAnchors: drift.Value(List<int>.from(reverse_anchors)),
        isClipped: const drift.Value(true),
        clippedAt: drift.Value(DateTime.now()),
        labelId: drift.Value(labelId),
      ),
      onConflict: drift.DoUpdate((old) => CommentsCompanion.custom(
        isClipped: const drift.Constant(true),
        clippedAt: drift.Constant(DateTime.now()),
        labelId: drift.Constant(labelId),
        // 本文なども最新化
        body: drift.Constant(commentBody),
        plus: drift.Constant(plus),
        minus: drift.Constant(minus),
      )),
    );
  });
}

Future<void> removeClippedComment(int topicId, int commentNo) async {
  await db.toggleClip(topicId, commentNo, false);
}

Future<void> updateClippedCommentMemo(int topicId, int commentNo, String memo) async {
  await (db.update(db.comments)..where((c) => c.topicId.equals(topicId) & c.number.equals(commentNo))).write(
    CommentsCompanion(clipMemo: drift.Value(memo)),
  );
}

Future<void> updateClippedCommentStats({
  required int topicId,
  required int commentNo,
  required int plus,
  required int minus,
  required List<dynamic> anchors,
  required List<dynamic> reverse_anchors,
}) async {
  await (db.update(db.comments)..where((c) => c.topicId.equals(topicId) & c.number.equals(commentNo))).write(
    CommentsCompanion(
      plus: drift.Value(plus),
      minus: drift.Value(minus),
      anchors: drift.Value(List<int>.from(anchors)),
      reverseAnchors: drift.Value(List<int>.from(reverse_anchors)),
    ),
  );
}

// ========== クリップラベル関連 ==========

const String kMyCommentsLabelName = '📝マイコメント';

Future<List<Map<String, dynamic>>> getClipLabels() async {
  final labels = await db.select(db.clipLabels).get();
  final list = labels.map((l) => {
    'id': l.id,
    'name': l.name,
    'createdAt': l.createdAt.toIso8601String(),
  }).toList();

  // デフォルトラベル(ID:0)はDBに含まれない場合があるので、なければ追加
  if (!list.any((l) => l['id'] == 0)) {
    list.insert(0, {'id': 0, 'name': '', 'createdAt': DateTime.now().toIso8601String()});
  }
  return list;
}

Future<int> getOrCreateMyCommentLabel() async {
  final labels = await getClipLabels();
  final existing = labels.firstWhere(
    (l) => l['name'] == kMyCommentsLabelName,
    orElse: () => {},
  );

  if (existing.isNotEmpty) {
    return existing['id'] as int;
  }

  await addClipLabel(kMyCommentsLabelName);
  final newLabels = await getClipLabels();
  final newLabel = newLabels.firstWhere((l) => l['name'] == kMyCommentsLabelName);
  return newLabel['id'] as int;
}

Future<bool> isMyCommentLabel(int labelId) async {
  if (labelId == 0) return false;
  final labels = await getClipLabels();
  final label = labels.firstWhere((l) => l['id'] == labelId, orElse: () => {});
  return label.isNotEmpty && label['name'] == kMyCommentsLabelName;
}

Future<void> addClipLabel(String name) async {
  await db.into(db.clipLabels).insert(ClipLabelsCompanion.insert(name: name));
}

Future<void> updateClipLabel(int id, String name) async {
  if (id == 0) return;
  await (db.update(db.clipLabels)..where((l) => l.id.equals(id))).write(
    ClipLabelsCompanion(name: drift.Value(name)),
  );
}

Future<void> deleteClipLabel(int id) async {
  if (id == 0) return;
  
  // 1. ラベル削除
  await (db.delete(db.clipLabels)..where((l) => l.id.equals(id))).go();
  
  // 2. 削除されたラベルのクリップをデフォルト(0)に移動
  await (db.update(db.comments)..where((c) => c.labelId.equals(id))).write(
    const CommentsCompanion(labelId: drift.Value(0)),
  );
}

Future<void> importClipDirectly(Map<String, dynamic> clipData) async {
  // インポート機能：Mapから復元
  final topicId = clipData['topicId'] as int;
  final commentNo = clipData['no'] as int;
  
  await addClippedComment(
    topicId: topicId,
    topicTitle: clipData['topicTitle'] ?? '',
    commentNo: commentNo,
    commentBody: clipData['body'] ?? '',
    posted_at: clipData['posted_at'] ?? '',
    name: clipData['name'] ?? '',
    plus: clipData['plus'] ?? 0,
    minus: clipData['minus'] ?? 0,
    anchors: clipData['anchors'] ?? [],
    reverse_anchors: clipData['reverse_anchors'] ?? [],
    imageUrl: clipData['image_url'],
    labelId: clipData['labelId'] ?? 0,
  );
  
  if (clipData['memo'] != null) {
    await updateClippedCommentMemo(topicId, commentNo, clipData['memo']);
  }
}

// ========== 追加: UI用ヘルパー ==========

/// トピックのメタ情報をDBから取得（キャッシュ代わり）
Future<Map<String, dynamic>?> getTopicMetaFromDb(int topicId) async {
  final topic = await (db.select(db.topics)..where((t) => t.id.equals(topicId))).getSingleOrNull();
  if (topic == null) return null;
  
  return {
    'total': topic.commentCount,
    'posted_at': topic.postedAt,
    'thumb': topic.thumbnail,
  };
}

Future<bool> hasCachedCommentsInDb(int topicId) async {
  final count = await (db.select(db.comments)..where((c) => c.topicId.equals(topicId))..limit(1)).get().then((l) => l.length);
  return count > 0;
}

Future<DateTime?> getTopicFetchedAt(int topicId) async {
  final topic = await (db.select(db.topics)..where((t) => t.id.equals(topicId))).getSingleOrNull();
  return topic?.fetchedAt;
}

Future<List<Map<String, dynamic>>> getCommentsFromDb(int topicId) async {
  final comments = await db.getCommentsForTopic(topicId);
  return comments.map((c) => {
    'no': c.number,
    'body': c.body,
    'name': c.name,
    'posted_at': c.postedAt,
    'plus': c.plus,
    'minus': c.minus,
    'image_url': c.imageUrl,
    'anchors': c.anchors,
    'reverse_anchors': c.reverseAnchors,
  }).toList();
}

Future<void> deleteTopicComments(int topicId) async {
  await (db.delete(db.comments)..where((c) => c.topicId.equals(topicId))).go();
}
