import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static const int cacheValidityMinutes = 60; // キャッシュの有効期限（分）

  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name.json');
  }

  static Future<File> _metaFile(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name.meta.json');
  }

  static Future<List<dynamic>> load(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
        // メタファイルで有効期限をチェック
        final isValid = await _isCacheValid(name);
        if (!isValid) {
          await clear(name);
          return [];
        }
        
        final text = await file.readAsString();
        return jsonDecode(text);
      }
    } catch (e) {
      print('Cache load error: $e');
    }
    return [];
  }

  static Future<void> save(String name, Object data) async {
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(data));
      
      // メタファイルに保存時刻を記録
      final metaFile = await _metaFile(name);
      await metaFile.writeAsString(jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      print('Cache save error: $e');
    }
  }

  static Future<bool> _isCacheValid(String name) async {
    try {
      final metaFile = await _metaFile(name);
      if (await metaFile.exists()) {
        final text = await metaFile.readAsString();
        final meta = jsonDecode(text) as Map<String, dynamic>;
        final savedAt = DateTime.parse(meta['savedAt'] as String);
        final now = DateTime.now();
        final diff = now.difference(savedAt).inMinutes;
        return diff < cacheValidityMinutes;
      }
    } catch (e) {
      print('Meta file check error: $e');
    }
    return false;
  }

  // キャッシュが存在するかチェック
  static Future<bool> exists(String name) async {
    try {
      final file = await _file(name);
      return await file.exists();
    } catch (e) {
      print('Cache exists check error: $e');
      return false;
    }
  }

  static Future<void> clear(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
      
      final metaFile = await _metaFile(name);
      if (await metaFile.exists()) await metaFile.delete();
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
