import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime? modified;
  _CacheEntry(this.data, this.modified);
}

class CacheService {
  static bool _initialized = false;
  
  // メモリキャッシュ
  static final Map<String, _CacheEntry> _memoryCache = {};
  // ファイル存在確認用キャッシュ
  static final Set<String> _knownFiles = {};
  // SharedPreferencesインスタンス
  static SharedPreferences? _prefs;

  /// SharedPreferencesのインスタンスを取得（シングルトン）
  static Future<SharedPreferences> getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// キャッシュディレクトリを初期化して情報を出力
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final dir = await getApplicationSupportDirectory();
      
      // ディレクトリが存在しなければ作成
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // ディレクトリ内のファイル一覧を取得して _knownFiles を構築
      final files = dir.listSync();
      for (var file in files) {
        if (file is File) {
          final name = file.path.split(Platform.pathSeparator).last;
          if (name.endsWith('.json')) {
            // .json を除いた名前を登録
            _knownFiles.add(name.substring(0, name.length - 5));
          }
        }
      }
    } catch (e) {
      // logd('❌ キャッシュ初期化エラー: $e');
    }
  }

  static Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name.json');
  }

  /// List キャッシュ用（コメント配列など）
  static Future<List<dynamic>> loadList(String name) async {
    // 1. メモリキャッシュ確認
    if (_memoryCache.containsKey(name)) {
      final data = _memoryCache[name]!.data;
      if (data is List) return data;
    }

    try {
      final file = await _file(name);
      if (_knownFiles.contains(name) || await file.exists()) {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        final stat = await file.stat();
        
        // メモリに保存
        _memoryCache[name] = _CacheEntry(decoded, stat.modified);
        _knownFiles.add(name); // 念のため

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
      
      // メモリ更新
      _memoryCache[name] = _CacheEntry(data, DateTime.now());
      _knownFiles.add(name);
    } catch (e) {
      logd('❌ saveList error: $e');
    }
  }

  /// Map キャッシュ用（メタ情報など）
  static Future<Map<String, dynamic>?> loadMap(String name) async {
    if (_memoryCache.containsKey(name)) {
      final data = _memoryCache[name]!.data;
      if (data is Map<String, dynamic>) return data;
    }

    try {
      final file = await _file(name);
      if (_knownFiles.contains(name) || await file.exists()) {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        final stat = await file.stat();

        _memoryCache[name] = _CacheEntry(decoded, stat.modified);
        _knownFiles.add(name);

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
      
      _memoryCache[name] = _CacheEntry(data, DateTime.now());
      _knownFiles.add(name);
      logd('💾 [saveMap] ✅ Saved: $name');
    } catch (e) {
      logd('❌ saveMap error: $e');
    }
  }

  /// int キャッシュ用（単一値など）
  static Future<int?> loadInt(String name) async {
    if (_memoryCache.containsKey(name)) {
      final data = _memoryCache[name]!.data;
      if (data is int) return data;
    }

    try {
      final file = await _file(name);
      if (_knownFiles.contains(name) || await file.exists()) {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        final stat = await file.stat();

        _memoryCache[name] = _CacheEntry(decoded, stat.modified);
        _knownFiles.add(name);

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
      
      _memoryCache[name] = _CacheEntry(data, DateTime.now());
      _knownFiles.add(name);
    } catch (e) {
      logd('❌ saveInt error: $e');
    }
  }

  // キャッシュが存在するかチェック
  static Future<bool> exists(String name) async {
    // メモリまたは既知のファイルリストにあれば true
    if (_memoryCache.containsKey(name) || _knownFiles.contains(name)) {
      return true;
    }
    
    // 念のためファイルシステムもチェック（初期化漏れなどの場合）
    try {
      final file = await _file(name);
      final exists = await file.exists();
      if (exists) _knownFiles.add(name);
      return exists;
    } catch (e) {
      return false;
    }
  }

  /// キャッシュファイルの作成/更新日時を取得
  static Future<DateTime?> getModifiedTime(String name) async {
    if (_memoryCache.containsKey(name)) {
      return _memoryCache[name]!.modified;
    }

    try {
      final file = await _file(name);
      if (_knownFiles.contains(name) || await file.exists()) {
        final stat = await file.stat();
        // メモリにはデータがないので日時だけキャッシュはできない（データ構造上）
        // 必要ならロードするが、ここではstatだけ返す
        return stat.modified;
      }
    } catch (e) {
      // logd('❌ getModifiedTime error: $e');
    }
    return null;
  }

  static Future<void> clear(String name) async {
    try {
      _memoryCache.remove(name);
      _knownFiles.remove(name);

      final file = await _file(name);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      logd('Cache clear error: $e');
    }
  }

  // ========== 下書き関連メソッド ==========

  /// 下書きを保存
  static Future<void> saveDraft(int topicId, String text) async {
    final name = 'draft_$topicId';
    try {
      final file = await _file(name);
      await file.writeAsString(jsonEncode(text));
      
      _memoryCache[name] = _CacheEntry(text, DateTime.now());
      _knownFiles.add(name);
      
      logd('💾 [saveDraft] ✅ Saved draft for topic $topicId');
    } catch (e) {
      logd('❌ saveDraft error: $e');
    }
  }

  /// 下書きを読み込む
  static Future<String?> loadDraft(int topicId) async {
    final name = 'draft_$topicId';
    if (_memoryCache.containsKey(name)) {
      final data = _memoryCache[name]!.data;
      if (data is String) return data;
    }

    try {
      final file = await _file(name);
      if (_knownFiles.contains(name) || await file.exists()) {
        final text = await file.readAsString();
        final decoded = jsonDecode(text);
        final stat = await file.stat();

        _memoryCache[name] = _CacheEntry(decoded, stat.modified);
        _knownFiles.add(name);

        if (decoded is String) {
          logd('💾 [loadDraft] ✅ Loaded draft for topic $topicId');
          return decoded;
        }
      }
    } catch (e) {
      logd('❌ loadDraft error: $e');
    }
    return null;
  }

  /// 下書きを削除
  static Future<void> deleteDraft(int topicId) async {
    final name = 'draft_$topicId';
    try {
      _memoryCache.remove(name);
      _knownFiles.remove(name);

      final file = await _file(name);
      if (await file.exists()) {
        await file.delete();
        logd('💾 [deleteDraft] ✅ Deleted draft for topic $topicId');
      }
    } catch (e) {
      logd('❌ deleteDraft error: $e');
    }
  }

  /// 下書きが存在するかチェック
  static Future<bool> hasDraft(int topicId) async {
    return exists('draft_$topicId');
  }
}
