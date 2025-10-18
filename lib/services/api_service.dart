import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiBase = AppConfig.apiBase;

// ========== コメント評価 ==========

// ========== コメント評価 ==========

Future<bool> rateComment(int topicId, String commentId, int value) async {
  try {
    final url = 'https://girlschannel.net/topics/post_value?value=$value&topic_id=$topicId&comment_id=$commentId';
    print('Request URL: $url');
    
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
    
    print('Rate response: ${response.statusCode}');
    print('Rate response body: ${response.body}');
    
    if (response.statusCode == 200) {
      if (response.body.isEmpty) {
        return true;
      }
      try {
        final data = jsonDecode(response.body);
        print('Parsed JSON: $data');
        return data['result'] == true;
      } catch (e) {
        print('JSON parse error: $e');
        return true;
      }
    }
    return false;
  } catch (e) {
    print('Rate error: $e');
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
    
    print('🌐 Search API URL: $uri');
    print('📍 API Base: $apiBase');
    
    final response = await http.get(uri).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception('タイムアウト: API応答がありません'),
    );
    
    print('📡 Response status: ${response.statusCode}');
    print('📦 Response body: ${response.body.substring(0, min(200, response.body.length))}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to search topics: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Search error: $e');
    rethrow;
  }
}

Future<List<dynamic>> fetchNewTopics() async {
  final response = await http.get(Uri.parse('$apiBase/topics/new'));
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load topics');
  }
}

// キャッシュ対応のトピック取得
Future<List<dynamic>> fetchNewTopicsWithCache() async {
  try {
    final response = await http.get(Uri.parse('$apiBase/topics/new'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // キャッシュに保存
      await CacheService.save('new_topics', data);
      return data;
    } else {
      throw Exception('Failed to load topics');
    }
  } catch (e) {
    // エラー時はキャッシュから取得
    final cached = await CacheService.load('new_topics');
    if (cached.isNotEmpty) {
      return cached;
    }
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
    final uri = Uri.parse('$apiBase/topic/$topicId').replace(
      queryParameters: {
        'offset': offset.toString(),
        'limit': limit.toString(),
      },
    );
    print('📥 Fetching comments: $uri');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final comments = data['comments'] as List<dynamic>? ?? [];
      final total = data['total'] as int? ?? comments.length;
      
      print('✅ Fetched ${comments.length} comments (total: $total)');
      
      return {
        'comments': comments,
        'total': total,
        'offset': offset,
        'limit': limit,
      };
    } else {
      throw Exception('Failed to load comments');
    }
  } catch (e) {
    print('❌ Pagination error: $e');
    rethrow;
  }
}

// キャッシュ対応のコメント取得（旧版、互換性維持）
Future<List<dynamic>> fetchCommentsWithCache(int topicId, {int limit = 10000}) async {
  try {
    final uri = Uri.parse('$apiBase/topic/$topicId').replace(
      queryParameters: {'limit': limit.toString()},
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final comments = data['comments'] ?? [];
      // キャッシュに保存
      await CacheService.save('comments_$topicId', comments);
      return comments;
    } else {
      throw Exception('Failed to load comments');
    }
  } catch (e) {
    // エラー時はキャッシュから取得
    final cached = await CacheService.load('comments_$topicId');
    if (cached.isNotEmpty) {
      return cached;
    }
    rethrow;
  }
}

// ========== 履歴リスト関連（旧「お気に入りトピック」） ==========

/// 履歴のトピック完全情報を取得
Future<List<Map<String, dynamic>>> getWatchedTopics() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList('watched_topics_full') ?? [];
  return jsonList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
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
