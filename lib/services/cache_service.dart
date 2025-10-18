import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name.json');
  }

  static Future<List<dynamic>> load(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
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
    } catch (e) {
      print('Cache save error: $e');
    }
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
