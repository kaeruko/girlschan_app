import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/log.dart';
import 'cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

final apiBase = AppConfig.apiBase;

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
    logd('');
    logd('============================================');
    logd('🔍 [searchTopics] API呼び出し開始');
    logd('============================================');
    logd('');
    
    final uri = Uri.parse('$apiBase/search').replace(
      queryParameters: {
        'q': query,
        'page': page.toString(),
        'count': count.toString(),
        if (dateFilter != null) 'date_filter': dateFilter,
      },
    );
    
    logd('🔍 [searchTopics] API URL: $uri');
    logd('� [searchTopics] Parameters:');
    logd('   - query: $query');
    logd('   - page: $page');
    logd('   - count: $count');
    if (dateFilter != null) logd('   - dateFilter: $dateFilter');
    logd('🔍 [searchTopics] API Base: $apiBase');
    
    final response = await http.get(uri).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('タイムアウト: API応答がありません'),
    );
    
    logd('� [searchTopics] Response status: ${response.statusCode}');
    logd('� [searchTopics] Response body (first 500 chars): ${response.body.substring(0, min(500, response.body.length))}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      logd('🔍 [searchTopics] ✅ Success');
      return data;
    } else {
      throw Exception('Failed to search topics: ${response.statusCode}');
    }
  } catch (e) {
    logd('🔍 [searchTopics] ❌ Error: $e');
    rethrow;
  }
}

Future<List<dynamic>> fetchNewTopics() async {
  try {
    final uri = '$apiBase/topics/new';
    logd('');
    logd('============================================');
    logd('📰 [fetchNewTopics] API呼び出し開始');
    logd('📰 [fetchNewTopics] API URL: $uri');
    logd('============================================');
    logd('');
    
    final response = await http.get(Uri.parse(uri));
    logd('📰 [fetchNewTopics] Response status: ${response.statusCode}');
    logd('📰 [fetchNewTopics] Response body (first 300 chars): ${response.body.substring(0, min(300, response.body.length))}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      logd('📰 [fetchNewTopics] ✅ Success - Fetched ${data.length} topics');
      return data;
    } else {
      throw Exception('Failed to load topics: ${response.statusCode}');
    }
  } catch (e) {
    logd('📰 [fetchNewTopics] ❌ Error: $e');
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
    
    final response = await http.get(Uri.parse(uri));
    logd('📰 [fetchNewTopicsWithCache] Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      logd('📰 [fetchNewTopicsWithCache] ✅ Success - Fetched ${data.length} topics');
      // キャッシュに保存
      await CacheService.saveList('new_topics', data);
      logd('📰 [fetchNewTopicsWithCache] 💾 Cached successfully');
      return data;
    } else {
      throw Exception('Failed to load topics: ${response.statusCode}');
    }
  } catch (e) {
    logd('📰 [fetchNewTopicsWithCache] ⚠️ Error occurred, attempting to load from cache: $e');
    // エラー時はキャッシュから取得
    final cached = await CacheService.loadList('new_topics');
    if (cached.isNotEmpty) {
      logd('📰 [fetchNewTopicsWithCache] 📂 Loaded from cache - ${cached.length} topics');
      return cached;
    }
    logd('📰 [fetchNewTopicsWithCache] ❌ No cache available');
    rethrow;
  }
}

// キャッシュ対応のコメント取得（ページング対応）
Future<Map<String, dynamic>> fetchCommentsWithPagination(
  int topicId, {
  int offset = 0,
  int limit = 10,
}) async {
  try {
    logd('');
    logd('============================================');
    logd('💬 [fetchCommentsWithPagination] API呼び出し開始');
    logd('============================================');
    logd('');
    
    final uri = Uri.parse('$apiBase/topic/$topicId').replace(
      queryParameters: {
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    logd('💬 [fetchCommentsWithPagination] API URL: $uri');
    logd('💬 [fetchCommentsWithPagination] Parameters: topicId=$topicId, offset=$offset, limit=$limit');
    
    final response = await http.get(uri);
    logd('💬 [fetchCommentsWithPagination] Response status: ${response.statusCode}');
    logd('💬 [fetchCommentsWithPagination] Response body length: ${response.body.length} bytes');
    
    if (response.statusCode == 200) {
      logd('💬 [fetchCommentsWithPagination] Parsing JSON...');
      final data = jsonDecode(response.body);
      final comments = data['comments'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? comments.length;
      
      logd('💬 [fetchCommentsWithPagination] ✅ Fetched ${comments.length} comments (total: $total)');
      logd('💬 [fetchCommentsWithPagination] Offset: $offset, Limit: $limit');
      
      // totalをメタキャッシュに保存（watched_topicsの更新用）
      await CacheService.saveMap('topic_meta_$topicId', {'total': total});
      logd('💬 [fetchCommentsWithPagination] 💾 Cached total: $total for topic $topicId');
      
      return {
        'comments': comments,
        'total': total,
        'offset': offset,
        'limit': limit,
      };
    } else {
      logd('💬 [fetchCommentsWithPagination] ❌ API Error status: ${response.statusCode}');
      throw Exception('Failed to load comments: ${response.statusCode}');
    }
  } catch (e) {
    logd('💬 [fetchCommentsWithPagination] ❌ Error: $e');
    rethrow;
  }
}

// キャッシュ対応のコメント取得（旧版、互換性維持）
Future<List<dynamic>> fetchCommentsWithCache(int topicId, {int limit = 10000}) async {
  try {
    logd('');
    logd('============================================');
    logd('💬 [fetchCommentsWithCache] API呼び出し開始');
    logd('============================================');
    logd('');
    
    final uri = Uri.parse('$apiBase/topic/$topicId').replace(
      queryParameters: {'limit': limit.toString()},
    );
    logd('💬 [fetchCommentsWithCache] API URL: $uri');
    logd('💬 [fetchCommentsWithCache] Parameters: topicId=$topicId, limit=$limit');
    
    final response = await http.get(uri);
    logd('💬 [fetchCommentsWithCache] Response status: ${response.statusCode}');
    logd('💬 [fetchCommentsWithCache] Response body length: ${response.body.length} bytes');
    
    if (response.statusCode == 200) {
      logd('💬 [fetchCommentsWithCache] Parsing JSON...');
      final data = jsonDecode(response.body);
      final comments = data['comments'] as List<dynamic>;
      final total = data['total'] as int? ?? comments.length;
      logd('💬 [fetchCommentsWithCache] ✅ Successfully parsed ${comments.length} comments (total: $total)');
      
      // コメントをキャッシュに保存
      await CacheService.saveList('comments_$topicId', comments);
      logd('💬 [fetchCommentsWithCache] 💾 Cached successfully - ${comments.length} comments stored');
      
      // totalをメタキャッシュに保存（watched_topicsの更新用）
      await CacheService.saveMap('topic_meta_$topicId', {'total': total});
      logd('💬 [fetchCommentsWithCache] 💾 Cached total: $total for topic $topicId');
      
      return comments;
    } else {
      logd('💬 [fetchCommentsWithCache] ❌ API Error status: ${response.statusCode}');
      throw Exception('Failed to load comments: ${response.statusCode}');
    }
  } catch (e) {
    logd('💬 [fetchCommentsWithCache] ⚠️ Error occurred, attempting to load from cache: $e');
    // エラー時はキャッシュから取得
    final cached = await CacheService.loadList('comments_$topicId');
    if (cached.isNotEmpty) {
      logd('💬 [fetchCommentsWithCache] 📂 Loaded from cache - ${cached.length} comments');
      return cached;
    }
    logd('💬 [fetchCommentsWithCache] ❌ No cache available');
    rethrow;
  }
}

// ========== 履歴リスト関連（旧「お気に入りトピック」） ==========

/// 履歴のトピック完全情報を取得
Future<List<Map<String, dynamic>>> getWatchedTopics() async {
  logd('');
  logd('============================================');
  logd('📋 [getWatchedTopics] Start');
  logd('============================================');
  logd('');
  
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];
  logd('📋 [getWatchedTopics] Loaded ${jsonList.length} topics from SharedPreferences');
  
  final topics = jsonList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  logd('📋 [getWatchedTopics] Parsed ${topics.length} topics');
  
  // 各トピックのメタキャッシュから最新のコメント数を取得
  for (final topic in topics) {
    final topicId = topic['id'] as int;
    logd('📋 [getWatchedTopics] Processing topic $topicId: ${topic['title']}');
    
    try {
      logd('📋 [getWatchedTopics] Loading meta cache for topic $topicId');
      final meta = await CacheService.loadMap('topic_meta_$topicId');
      
      if (meta != null) {
        final total = meta['total'] as int?;
        logd('📋 [getWatchedTopics] Got meta: total=$total');
        
        if (total != null) {
          logd('📋 [getWatchedTopics] Updating topic $topicId comments from ${topic['comments']} to $total');
          topic['comments'] = total;
        }
      } else {
        logd('📋 [getWatchedTopics] Meta cache is null for topic $topicId');
      }
    } catch (e, st) {
      logd('📋 [getWatchedTopics] ❌ Error processing topic $topicId: $e');
      logd('📋 [getWatchedTopics] Stack trace: $st');
    }
  }
  
  logd('📋 [getWatchedTopics] ✅ Complete');
  return topics;
}

/// 履歴のトピックIDリストを取得（後方互換性用）
Future<List<int>> getWatchedTopicIds() async {
  final prefs = await SharedPreferences.getInstance();
  // 新形式を試す
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];
  if (jsonList.isNotEmpty) {
    return jsonList
        .map((e) => (jsonDecode(e) as Map<String, dynamic>)['id'] as int)
        .toList();
  }
  // 旧形式から移行
  final ids = prefs.getStringList('watched_topics') ?? [];
  return ids.map(int.parse).toList();
}

/// 履歴に追加（完全情報を保存）
Future<void> addWatchedTopicId(
  int id, {
  String? title,
  String? url,
  int? comments,
  String? time,
  String? imageUrl,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];
  
  // 重複チェック
  final isDuplicate = jsonList.any((e) {
    final topic = jsonDecode(e) as Map<String, dynamic>;
    return topic['id'] == id;
  });
  
  if (!isDuplicate) {
    final topic = {
      'id': id,
      'title': title ?? 'トピック',
      'url': url ?? '',
      'comments': comments ?? 0,
      'time': time ?? '',
      'imageUrl': imageUrl,
      'watchedAt': DateTime.now().toIso8601String(),
    };
    jsonList.add(jsonEncode(topic));
    await prefs.setStringList('watched_topics_full', jsonList);
  }
}

/// 履歴から削除
Future<void> removeWatchedTopicId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];
  
  jsonList.removeWhere((e) {
    final topic = jsonDecode(e) as Map<String, dynamic>;
    return topic['id'] == id;
  });
  
  await prefs.setStringList('watched_topics_full', jsonList);
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
  required String time,
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
    'time': time,
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

Future<bool> isCommentClipped(int topicId, int commentNo) async {
  final clips = await getClippedComments();
  return clips.any((c) => c['topicId'] == topicId && c['no'] == commentNo);
}

// ========== 後方互換性（旧「お気に入り」→「履歴」に移行） ==========

Future<List<int>> getFavoriteIds() async {
  // 古いキーがあれば新しいキーに移行
  final prefs = await SharedPreferences.getInstance();
  final oldFavs = prefs.getStringList('favorites') ?? [];
  if (oldFavs.isNotEmpty) {
    await prefs.setStringList('watched_topics', oldFavs);
    await prefs.remove('favorites');
  }
  return getWatchedTopicIds();
}

Future<void> addFavoriteId(int id) async => addWatchedTopicId(id);
Future<void> removeFavoriteId(int id) async => removeWatchedTopicId(id);
