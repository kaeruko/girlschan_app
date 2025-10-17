import 'dart:convert';
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

// キャッシュ対応のコメント取得
Future<List<dynamic>> fetchCommentsWithCache(int topicId) async {
  try {
    final response = await http.get(Uri.parse('$apiBase/topic/$topicId'));
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

// ========== お気に入り関連 ==========

Future<List<int>> getFavoriteIds() async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList('favorites') ?? [];
  return ids.map(int.parse).toList();
}

Future<void> addFavoriteId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList('favorites') ?? [];
  if (!ids.contains(id.toString())) {
    ids.add(id.toString());
    await prefs.setStringList('favorites', ids);
  }
}

Future<void> removeFavoriteId(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final ids = prefs.getStringList('favorites') ?? [];
  ids.remove(id.toString());
  await prefs.setStringList('favorites', ids);
}
