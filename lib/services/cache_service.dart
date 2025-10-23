
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    // print('📂 Cache directory: ${dir.path}');
    return File('${dir.path}/$name.json');
  }
  
  /// List キャッシュ用（コメント配列など）
  static Future<List<dynamic>> loadList(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      print('❌ loadList error: $e');
    }
    return [];
  }

  /// List キャッシュ用（保存）
  static Future<void> saveList(String name, List<dynamic> data) async {
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(data));
      print('💾 [saveList] ✅ Saved: $name');
    } catch (e) {
      print('❌ saveList error: $e');
    }
  }

  /// Map キャッシュ用（メタ情報など）
  static Future<Map<String, dynamic>?> loadMap(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      print('❌ loadMap error: $e');
    }
    return null;
  }

  /// Map キャッシュ用（保存）
  static Future<void> saveMap(String name, Map<String, dynamic> data) async {
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(data));
      print('💾 [saveMap] ✅ Saved: $name');
    } catch (e) {
      print('❌ saveMap error: $e');
    }
  }

  /// int キャッシュ用（単一値など）
  static Future<int?> loadInt(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is int) {
          return decoded;
        }
        if (decoded is String) {
          return int.tryParse(decoded);
        }
      }
    } catch (e) {
      print('❌ loadInt error: $e');
    }
    return null;
  }

  /// int キャッシュ用（保存）
  static Future<void> saveInt(String name, int data) async {
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(data));
      print('💾 [saveInt] ✅ Saved: $name = $data');
    } catch (e) {
      print('❌ saveInt error: $e');
    }
  }

  // キャッシュが存在するかチェック
  static Future<bool> exists(String name) async {
    try {
      final file = await _file(name);
      final exists = await file.exists();
      // print('💾 [CacheService.exists] Checking: $name -> exists: $exists (path: ${file.path})');
      return exists;
    } catch (e) {
      print('❌ Cache exists check error: $e');
      return false;
    }
  }

  static Future<void> clear(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
    } catch (e) {
      print('Cache clear error: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final files = dir.listSync();
      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Clear all cache error: $e');
    }
  }
}
