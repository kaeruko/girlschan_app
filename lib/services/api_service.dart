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
    // logd('');
    // logd('============================================');
    // logd('⭐ [rateComment] API呼び出し開始');
    // logd('============================================');
    // logd('');
    
    final url = 'https://girlschannel.net/topics/post_value?value=$value&topic_id=$topicId&comment_id=$commentId';
    logd('⭐ [rateComment] Request URL: $url');
    // logd('⭐ [rateComment] Parameters: topicId=$topicId, commentId=$commentId, value=$value');
    
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
    
    // logd('⭐ [rateComment] Response status: ${response.statusCode}');
    // logd('⭐ [rateComment] Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        // logd('⭐ [rateComment] ✅ Success (empty body)');
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
    // logd('⭐ [rateComment] ❌ Failed with status ${response.statusCode}');
    return false;
  } catch (e) {
    // logd('⭐ [rateComment] ❌ Error: $e');
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
}) async {
  try {
    // logd('');
    // logd('============================================');
    // logd('💬 [fetchCommentsWithPagination] API呼び出し開始');
    // logd('============================================');
    // logd('');
    
    final uri = Uri.parse('$apiBase/topic/$topicId').replace(
      queryParameters: {
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    // logd('💬 [fetchCommentsWithPagination] API URL: $uri');
    // logd('💬 [fetchCommentsWithPagination] Parameters: topicId=$topicId, offset=$offset, limit=$limit');
    
    final data = await _fetchMap(uri);
    
    // logd('💬 [fetchCommentsWithPagination] Parsing JSON...');
    final comments = data['comments'] as List<dynamic>? ?? [];
    final total = data['total'] as int? ?? comments.length;
    final posted_at = data['posted_at'] as String? ?? '';
    
    // logd('💬 [fetchCommentsWithPagination] ✅ Fetched ${comments.length} comments (total: $total)');
    // logd('💬 [fetchCommentsWithPagination] Offset: $offset, Limit: $limit');
    
    // totalをメタキャッシュに保存（watched_topicsの更新用）
    await CacheService.saveMap('topic_meta_$topicId', {'total': total});
    // logd('💬 [fetchCommentsWithPagination] 💾 Cached total: $total for topic $topicId');
    
    return {
      'comments': comments,
      'total': total,
      'posted_at': posted_at,
      'offset': offset,
      'limit': limit,
    };
  } catch (e) {
    // logd('💬 [fetchCommentsWithPagination] ❌ Error: $e');
    rethrow;
  }
}

// ========== 履歴リスト関連（旧「お気に入りトピック」） ==========

// ========== 履歴関連（トピック履歴） ==========

Future<List<Map<String, dynamic>>> getWatchedTopics() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];

  final topics = jsonList
      .map((e) => jsonDecode(e) as Map<String, dynamic>)
      .toList();

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
      return; // watchedTopicsがなければスキップ
    }
    
    // APIから取得したトピックをMapに変換（IDをキーに）
    final fetchedMap = {
      for (final topic in fetchedTopics) 
        (topic['id'] as int): topic
    };
    
    // watchedTopicsを更新
    bool updated = false;
    for (int i = 0; i < jsonList.length; i++) {
      final watched = jsonDecode(jsonList[i]) as Map<String, dynamic>;
      final topicId = watched['id'] as int;
      
      if (fetchedMap.containsKey(topicId)) {
        final fetchedComments = fetchedMap[topicId]!['comments'] as int?;
        if (fetchedComments != null && 
            watched['comments'] != fetchedComments) {
          // コメント数が更新されていたら更新
          watched['comments'] = fetchedComments;
          jsonList[i] = jsonEncode(watched);
          updated = true;
          // logd('📝 [updateWatchedTopicsComments] Updated topic $topicId: ${watched['comments']} comments', name: 'WatchedUpdate');
        }
      }
    }
    
    if (updated) {
      await prefs.setStringList('watched_topics_full', jsonList);
      // logd('📝 [updateWatchedTopicsComments] ✅ Saved updated watched topics', name: 'WatchedUpdate');
    }
  } catch (e) {
    // logd('📝 [updateWatchedTopicsComments] ❌ Error: $e', name: 'WatchedUpdate');
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
