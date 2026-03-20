import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BlockService {
  static String _key(int topicId) => 'blocked_comments_$topicId';

  static Future<Set<int>> loadBlockedComments(int topicId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(topicId));
    if (raw == null) return {};
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => e as int).toSet();
  }

  static Future<void> addBlockedComment(int topicId, int commentId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadBlockedComments(topicId);
    current.add(commentId);
    await prefs.setString(_key(topicId), jsonEncode(current.toList()));
  }
}
