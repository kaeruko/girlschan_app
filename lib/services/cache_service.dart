import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../utils/log.dart';


class CacheService {
  static bool _initialized = false;

  /// キャッシュディレクトリを初期化して情報を出力
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final dir = await getApplicationSupportDirectory();
      // logd('');
      // logd('============================================');
      // logd('💾 キャッシュサービス初期化');
      // logd('============================================');
      // logd('📂 キャッシュディレクトリ: ${dir.path}');

      // ディレクトリが存在しなければ作成
      if (!await dir.exists()) {
        await dir.create(recursive: true);
        // logd('📂 ディレクトリを新規作成しました');
      }

      // ディレクトリ内のファイル一覧を表示
      final files = dir.listSync();
      // logd('📂 キャッシュファイル数: ${files.length}');
      for (int i = 0; i < files.length && i < 10; i++) {
        final file = files[i];
        if (file is File) {
          final size = await file.length();
          logd('  [$i] ${file.path.split('/').last} (${size} bytes)');
        }
      }
      if (files.length > 10) {
        // logd('  ... 他 ${files.length - 10}個のファイル');
      }
      // logd('============================================');
      // logd('');
    } catch (e) {
      // logd('❌ キャッシュ初期化エラー: $e');
    }
  }

  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    // logd('📂 キャッシュディレクトリ: ${dir.path}');
    return File('${dir.path}/$name.json');
  }

  /// List キャッシュ用（コメント配列など）
  static Future<List<dynamic>> loadList(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
        // print('💾 [loadList] Loading cache: $name');
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded;
        }
      }
    } catch (e) {
      // logd('❌ loadList error: $e');
    }
    return [];
  }

  /// List キャッシュ用（保存）
  static Future<void> saveList(String name, List<dynamic> data) async {
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(data));
      // logd('💾 [saveList] ✅ Saved: $name');
    } catch (e) {
      logd('❌ saveList error: $e');
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
      logd('❌ loadMap error: $e');
    }
    return null;
  }

  /// Map キャッシュ用（保存）
  static Future<void> saveMap(String name, Map<String, dynamic> data) async {
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(data));
      logd('💾 [saveMap] ✅ Saved: $name');
    } catch (e) {
      logd('❌ saveMap error: $e');
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
      logd('❌ loadInt error: $e');
    }
    return null;
  }

  /// int キャッシュ用（保存）
  static Future<void> saveInt(String name, int data) async {
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(data));
      // logd('💾 [saveInt] ✅ Saved: $name = $data');
    } catch (e) {
      logd('❌ saveInt error: $e');
    }
  }

  // キャッシュが存在するかチェック
  static Future<bool> exists(String name) async {
    try {
      final file = await _file(name);
      final exists = await file.exists();
      // デバッグログ: キャッシュ存在確認
      // ignore: avoid_print
      // print('[CacheService] exists: $name -> $exists (path: [36m${file.path}[0m)');
      return exists;
    } catch (e) {
      // logd('❌ Cache exists check error: $e');
      return false;
    }
  }

  /// キャッシュファイルの作成/更新日時を取得
  static Future<DateTime?> getModifiedTime(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
        final stat = file.statSync();
        // デバッグログ: キャッシュ更新日時取得
        // ignore: avoid_print
        // print('[CacheService] getModifiedTime: $name -> ${stat.modified} (path: [36m${file.path}[0m)');
        return stat.modified;
      }
    } catch (e) {
      // logd('❌ getModifiedTime error: $e');
    }
    return null;
  }

  static Future<void> clear(String name) async {
    try {
      final file = await _file(name);
      if (await file.exists()) {
        await file.delete();
        // デバッグログ: キャッシュ削除
        // ignore: avoid_print
        // print('[CacheService] clear: $name 削除 (path: [36m${file.path}[0m)');
      }
    } catch (e) {
      logd('Cache clear error: $e');
    }
  }
}
