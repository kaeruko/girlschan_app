import 'dart:async';
import 'package:http/http.dart' as http;
import '../utils/log.dart';

class AppConfig {
  static late String apiBase;

  static const String googleDriveFileId = '1XYsfmC3A0qtVbGgEmCvtmQvL0Qm405x1';
  // 既存のgetterは使わず、fetch内で確実にキャッシュバスターを付ける
  static String get googleDriveDownloadUrl =>
      'https://drive.google.com/uc?export=download&id=$googleDriveFileId';

  static const String cacheDirName = 'cache';
  static const String favoritesFile = 'favorites.json';
  static const String favoritesDataFile = 'favorites_data.json';
  static const int defaultLimit = 100;
  static const String appTitle = 'TalkBoard';
  static const double cornerRadius = 12.0;

  static Future<void> initializeApiBase() async {
    try {
      final response = await _fetchApiBaseFromGoogleDrive();
      apiBase = response.trim();
    } catch (e) {
      logd('エラー: Google Drive から apiBase の読み込みに失敗しました: $e');
      apiBase = '';
    }
  }

  static Future<String> _fetchApiBaseFromGoogleDrive() async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();

    // ✅ Driveはクエリにキャッシュバスターを付けるのが効く（&t=...）
    final uri = Uri.https('drive.google.com', '/uc', {
      'export': 'download',
      'id': googleDriveFileId,
      't': ts,
    });

    logd('📥 Google Drive から読み込み開始: $uri');

    try {
      // ✅ 初回TLS/リダイレクトで遅れやすいので12〜15秒に
      final res = await http.get(uri).timeout(const Duration(seconds: 12));

      logd('📊 ステータスコード: ${res.statusCode}');
      logd('📋 レスポンスボディ長: ${res.body.length} 文字');

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      // 1行URL想定：先頭の非空行だけ採用
      final text = res.body.trim();
      final firstLine = text.split('\n').first.trim();
      return firstLine;
    } on TimeoutException {
      throw Exception('タイムアウト: 12秒以内に応答なし');
    } catch (e) {
      logd('❌ Google Drive 読み込みエラー詳細: $e');
      rethrow;
    }
  }
}
