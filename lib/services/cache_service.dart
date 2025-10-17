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

  static Future<void> clear(String name) async {
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }
}
