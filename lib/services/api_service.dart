import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/log.dart';
import 'cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiBase = AppConfig.apiBase;

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
    logd('⭐ [rateComment] Parameters: topicId=$topicId, commentId=$commentId, value=$value');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'ja,en-US;q=0.9,en;q=0.8',
        'dnt': '1',
        'priority': 'u=1, i',
        'referer': 'https://girlschannel.net/topics/$topicId/',
        'sec-ch-ua': '"Chromium";v="141", "Not?A_Brand";v="8"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"Android"',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent': 'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 CrKey/1.54.248666',
      },
    );
    
    logd('⭐ [rateComment] Response status: ${response.statusCode}');
    logd('⭐ [rateComment] Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        logd('⭐ [rateComment] ✅ Success (empty body)');
        return true;
      }
      try {
        final data = jsonDecode(response.body);
        logd('⭐ [rateComment] Parsed JSON: $data');
        return data['result'] == true;
      } catch (e) {
        logd('⭐ [rateComment] ⚠️ JSON parse error: $e');
        return true;
      }
    }
    logd('⭐ [rateComment] ❌ Failed with status ${response.statusCode}');
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
    // logd('');
    // logd('============================================');
    // logd('🔍 [searchTopics] API呼び出し開始');
    // logd('============================================');
    // logd('');
    
    final uri = Uri.parse('$apiBase/search').replace(
      queryParameters: {
        'q': query,
        'page': page.toString(),
        'count': count.toString(),
        if (dateFilter != null) 'date_filter': dateFilter,
      },
    );
    
    // logd('🔍 [searchTopics] API URL: $uri');
    // logd('� [searchTopics] Parameters:');
    // logd('   - query: $query');
    // logd('   - page: $page');
    // logd('   - count: $count');
    if (dateFilter != null) logd('   - dateFilter: $dateFilter');
    // logd('🔍 [searchTopics] API Base: $apiBase');
    
    final data = await _fetchMap(uri);
    
    // logd('🔍 [searchTopics] ✅ Success');
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

  logd('📡 [fetchTopicMeta] Response: ${resp.body}', name: 'API');

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
  final newThumb = meta['thumb'];
  final newPostedAt = meta['posted_at'];
  final newFetchedAt = meta['fetched_at'];

  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];

  bool updated = false;
  bool hasNewComments = false;

  for (int i = 0; i < jsonList.length; i++) {
    final watched = jsonDecode(jsonList[i]) as Map<String, dynamic>;
    if (watched['id'] != topicId) continue;

    final oldTotal = (watched['comments'] as int?) ?? 0;
    if (newTotal > oldTotal) {
      hasNewComments = true;
    }

    // コメント数
    watched['comments'] = newTotal;

    // 投稿日・サムネはあれば上書き
    if (newPostedAt is String && newPostedAt.isNotEmpty) {
      watched['posted_at'] = newPostedAt;
    }
    if (newFetchedAt is String && newFetchedAt.isNotEmpty) {
      watched['fetched_at'] = newFetchedAt;
    }
    if (newThumb is String && newThumb.isNotEmpty) {
      watched['thumb'] = newThumb;
    }

    jsonList[i] = jsonEncode(watched);
    updated = true;
    break;
  }

  if (updated) {
    await prefs.setStringList('watched_topics_full', jsonList);
  }

  return hasNewComments;
}


// キャッシュ対応のトピック取得
Future<List<dynamic>> fetchNewTopicsWithCache() async {
  try {
    logd('');
    logd('============================================');
    logd('📰 [fetchNewTopicsWithCache] API呼び出し開始');
    logd('============================================');
    logd('');
    
    final uri = '$apiBase/topics/new';
    logd('📰 [fetchNewTopicsWithCache] API URL: $uri');
    
    final data = await _fetchList(Uri.parse(uri));
    
    // ⚠️ キャッシュへの保存はUI側（TopicListScreen）で一本化
    // logd('📰 [fetchNewTopicsWithCache] (キャッシュ保存は UI 側で処理)');
    return data;
  } catch (e) {
    // logd('📰 [fetchNewTopicsWithCache] ❌ Error: $e');
    rethrow; // ← UI側で cacheKey を使ってキャッシュから拾う
  }
}

/// キャッシュ対応の人気トピック取得
Future<List<dynamic>> fetchPopularTopicsWithCache() async {
  try {
    // logd('');
    // logd('============================================');
    // logd('⭐ [fetchPopularTopicsWithCache] API呼び出し開始');
    // logd('============================================');
    // logd('');
    
    final uri = '$apiBase/topics/popular';
    // logd('⭐ [fetchPopularTopicsWithCache] API URL: $uri');
    
    final data = await _fetchList(Uri.parse(uri));
    
    // logd('⭐ [fetchPopularTopicsWithCache] ✅ Success - Fetched ${data.length} topics');
    // ⚠️ キャッシュへの保存はUI側（TopicListScreen）で一本化
    // logd('⭐ [fetchPopularTopicsWithCache] (キャッシュ保存は UI 側で処理)');
    return data;
  } catch (e) {
    // logd('⭐ [fetchPopularTopicsWithCache] ❌ Error: $e');
    rethrow; // ← UI側で cacheKey を使ってキャッシュから拾う
  }
}

// キャッシュ対応のコメント取得（ページング対応）
Future<Map<String, dynamic>> fetchCommentsWithPagination(
  int topicId, {
  int offset = 0,
  int limit = 10,
  bool old = false,
}) async {
  try {
    // logd('');
    // logd('============================================');
    // logd('💬 [fetchCommentsWithPagination] API呼び出し開始');
    // logd('============================================');
    // logd('');
    
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
    // logd('💬 [fetchCommentsWithPagination] API URL: $uri');
    // logd('💬 [fetchCommentsWithPagination] Parameters: topicId=$topicId, offset=$offset, limit=$limit');
    
    final data = await _fetchMap(uri);
    
    // logd('💬 [fetchCommentsWithPagination] Parsing JSON...');
    final comments = data['comments'] as List<dynamic>? ?? [];
    final total = data['total'] as int? ?? comments.length;
    
    // ★追加: Python側から返ってくる新しいフィールドを取得
    final posted_at = data['posted_at'] as String? ?? '';
    final thumb = data['thumb'] as String?; // nullの場合もあるので nullable

    // logd('💬 [fetchCommentsWithPagination] ✅ Fetched ${comments.length} comments (total: $total)');
    // logd('💬 [fetchCommentsWithPagination] Offset: $offset, Limit: $limit');
    
    // ★修正: totalだけでなく、サムネや日時もメタキャッシュに保存しておく
    await CacheService.saveMap('topic_meta_$topicId', {
      'total': total,
      'posted_at': posted_at,
      'thumb': thumb,
    });
    // logd('💬 [fetchCommentsWithPagination] 💾 Cached meta for topic $topicId');
    
    return {
      'comments': comments,
      'total': total,
      'posted_at': posted_at,
      'thumb': thumb, // ★戻り値に追加
      'offset': offset,
      'limit': limit,
    };
  } catch (e) {
    // logd('💬 [fetchCommentsWithPagination] ❌ Error: $e');
    rethrow;
  }
}

/// 指定されたコメントのスレッド（アンカー先・元など）を取得
Future<Map<String, dynamic>> fetchCommentThread(int topicId, int commentId) async {
  try {
    // logd('');
    // logd('============================================');
    // logd('🧵 [fetchCommentThread] API呼び出し開始');
    // logd('============================================');
    // logd('');

    final uri = Uri.parse('$apiBase/comment/$topicId/$commentId');
    // logd('🧵 [fetchCommentThread] API URL: $uri');

    final data = await _fetchMap(uri);

    // logd('🧵 [fetchCommentThread] ✅ Success - Fetched ${data['count']} comments');
    return data;
  } catch (e) {
    // logd('🧵 [fetchCommentThread] ❌ Error: $e');
    rethrow;
  }
}
// ========== 履歴関連（トピック履歴） ==========

Future<List<Map<String, dynamic>>> getWatchedTopics() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];

  final topics = jsonList
      .map((e) => jsonDecode(e) as Map<String, dynamic>)
      .toList();

  for (final t in topics) {
    // logd('📂 [getWatchedTopics] id=${t['id']} title=${t['title']} posted_at=${t['posted_at']} fetched_at=${t['fetched_at']}');
  }

  // watchedAt があれば、クリップと同じように新しい順にソート
  topics.sort((a, b) {
    DateTime parseDate(String? s) {
      if (s == null || s.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      try {
        return DateTime.parse(s);
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    return parseDate(b['watchedAt'] as String?)
        .compareTo(parseDate(a['watchedAt'] as String?));
  });

  return topics;
}

Future<List<int>> getWatchedTopicIds() async {
  final topics = await getWatchedTopics();
  return topics
      .map((topic) => topic['id'])
      .whereType<int>()
      .toList();
}

Future<void> addWatchedTopic({
  required int id,
  required String title,
  required int comments,
  required String posted_at,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];

  final isDuplicate = jsonList.any((e) {
    final topic = jsonDecode(e) as Map<String, dynamic>;
    return topic['id'] == id;
  });

  if (!isDuplicate) {
    final topic = {
      'id': id,
      'title': title,
      'comments': comments,
      'posted_at': posted_at,
      'watchedAt': DateTime.now().toIso8601String(),
    };
    jsonList.add(jsonEncode(topic));
    await prefs.setStringList('watched_topics_full', jsonList);
  }
}

Future<void> removeWatchedTopicId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];

  jsonList.removeWhere((e) {
    final topic = jsonDecode(e) as Map<String, dynamic>;
    return topic['id'] == id;
  });

  await prefs.setStringList('watched_topics_full', jsonList);

  // 旧 watched_topics も整理したいならついでに消す
  final legacy = prefs.getStringList('watched_topics') ?? [];
  if (legacy.isNotEmpty) {
    final filtered = legacy.where((s) => int.tryParse(s) != id).toList();
    await prefs.setStringList('watched_topics', filtered);
  }
}

/// APIから取得したトピックリストで、watchedTopicsのコメント数を更新
Future<void> updateWatchedTopicsComments(
  List<Map<String, dynamic>> fetchedTopics,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('watched_topics_full') ?? [];
    
    if (jsonList.isEmpty) {
      return;
    }
    
    final fetchedMap = {
      for (final topic in fetchedTopics) 
        (topic['id'] as int): topic
    };
    
    bool updated = false;
    for (int i = 0; i < jsonList.length; i++) {
      final watched = jsonDecode(jsonList[i]) as Map<String, dynamic>;
      final topicId = watched['id'] as int;
      
      if (fetchedMap.containsKey(topicId)) {
        final fetchedComments = fetchedMap[topicId]!['comments'] as int?;
        
        if (fetchedComments != null ) {          
          watched['comments'] = fetchedComments;
          jsonList[i] = jsonEncode(watched);
          updated = true;
        }
      }
    }
    
    if (updated) {
      await prefs.setStringList('watched_topics_full', jsonList);
    }
  } catch (e) {
    // エラー処理
  }
}

/// トピックを閲覧したとして、watchedAt（最終閲覧日時）を現在時刻に更新する
Future<void> touchWatchedTopic(int topicId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList('watched_topics_full') ?? [];
    
    bool updated = false;
    
    // リストを走査して該当IDを探す
    for (int i = 0; i < jsonList.length; i++) {
      final Map<String, dynamic> topic = jsonDecode(jsonList[i]);
      
      if (topic['id'] == topicId) {
        // 日時を現在時刻に更新
        topic['watchedAt'] = DateTime.now().toIso8601String();
        
        // リストを更新
        jsonList[i] = jsonEncode(topic);
        updated = true;
        break; // IDはユニークなので見つかったら終了
      }
    }
    
    if (updated) {
      // 更新があった場合のみ保存
      await prefs.setStringList('watched_topics_full', jsonList);
      // logd('👆 [touchWatchedTopic] Updated timestamp for ID: $topicId');
    }
  } catch (e) {
    // logd('❌ [touchWatchedTopic] Error: $e');
  }
}

/// 履歴全体を削除
Future<void> clearWatchedHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final hadFull = prefs.containsKey('watched_topics_full');
  final hadIds = prefs.containsKey('watched_topics');
  await prefs.remove('watched_topics_full');
  await prefs.remove('watched_topics'); // 旧形式も一緒に消す
  logd('🧹 [clearWatchedHistory] full=$hadFull, ids=$hadIds → cleared', name: 'ClearHistory');
}

// ========== クリップ関連（コメント保存） ==========

Future<List<Map<String, dynamic>>> getClippedComments() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('clipped_comments') ?? [];
  return jsonList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
}

Future<void> addClippedComment({
  required int topicId,
  required String topicTitle,
  required int commentNo,
  required String commentBody,
  required String posted_at,
  required int plus,
  required int minus,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final clips = prefs.getStringList('clipped_comments') ?? [];
  
  final clip = {
    'topicId': topicId,
    'topicTitle': topicTitle,
    'no': commentNo,
    'body': commentBody,
    'posted_at': posted_at,
    'plus': plus,
    'minus': minus,
    'clipDate': DateTime.now().toIso8601String(),
  };
  
  // 重複チェック（同じトピックの同じコメント）
  final isDuplicate = clips.any((e) {
    final existing = jsonDecode(e) as Map<String, dynamic>;
    return existing['topicId'] == topicId && existing['no'] == commentNo;
  });
  
  if (!isDuplicate) {
    clips.add(jsonEncode(clip));
    await prefs.setStringList('clipped_comments', clips);
  }
}

Future<void> removeClippedComment(int topicId, int commentNo) async {
  final prefs = await SharedPreferences.getInstance();
  final clips = prefs.getStringList('clipped_comments') ?? [];
  
  clips.removeWhere((e) {
    final clip = jsonDecode(e) as Map<String, dynamic>;
    return clip['topicId'] == topicId && clip['no'] == commentNo;
  });
  
  await prefs.setStringList('clipped_comments', clips);
}

Future<void> updateClippedCommentMemo(int topicId, int commentNo, String memo) async {
  final prefs = await SharedPreferences.getInstance();
  final clips = prefs.getStringList('clipped_comments') ?? [];
  
  bool updated = false;
  for (int i = 0; i < clips.length; i++) {
    final clip = jsonDecode(clips[i]) as Map<String, dynamic>;
    if (clip['topicId'] == topicId && clip['no'] == commentNo) {
      clip['memo'] = memo;
      clips[i] = jsonEncode(clip);
      updated = true;
      break;
    }
  }
  
  if (updated) {
    await prefs.setStringList('clipped_comments', clips);
  }
}

Future<void> updateClippedCommentStats({
  required int topicId,
  required int commentNo,
  required int plus,
  required int minus,
  required List<dynamic> anchors,
  required List<dynamic> reverse_anchors,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final clips = prefs.getStringList('clipped_comments') ?? [];
  
  bool updated = false;
  for (int i = 0; i < clips.length; i++) {
    final clip = jsonDecode(clips[i]) as Map<String, dynamic>;
    if (clip['topicId'] == topicId && clip['no'] == commentNo) {
      clip['plus'] = plus;
      clip['minus'] = minus;
      clip['anchors'] = anchors;
      clip['reverse_anchors'] = reverse_anchors;
      clips[i] = jsonEncode(clip);
      updated = true;
      break;
    }
  }
  
  if (updated) {
    await prefs.setStringList('clipped_comments', clips);
  }
}
