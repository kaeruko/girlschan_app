import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final apiBase = AppConfig.apiBase;

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
