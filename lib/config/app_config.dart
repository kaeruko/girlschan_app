import 'package:http/http.dart' as http;
import '../utils/log.dart';

class AppConfig {
  // ==== 接続先API ====
  static late String apiBase;
  
  // Google Drive のファイル ID
  static const String googleDriveFileId = '1dxoVmKCEHnIRinUC2gK-YC3ZinRE9GnA';
  
  // Google Drive からの読み込み URL (ダウンロード形式)
  static String get googleDriveDownloadUrl =>
      'https://drive.google.com/uc?export=download&id=$googleDriveFileId';

  // ==== キャッシュ関連 ====
  static const String cacheDirName = 'cache';
  static const String favoritesFile = 'favorites.json';
  static const String favoritesDataFile = 'favorites_data.json';

  // ==== ページング ====
  static const int defaultLimit = 100;

  // ==== テーマ・UI ====
  static const String appTitle = 'TalkBoard';
  static const double cornerRadius = 12.0;
  
  /// Google Drive から apiBase を読み込み初期化
  static Future<void> initializeApiBase() async {
    try {
      final response = await _fetchApiBaseFromGoogleDrive();
      apiBase = response.trim();
      apiBase = 'http://192.168.40.171:5050/';
    } catch (e) {
      logd('エラー: Google Drive から apiBase の読み込みに失敗しました: $e');
      // フォールバック値を設定
      apiBase = 'http://192.168.40.171:5050/';
      // apiBase = 'https://evhch6a2hc.execute-api.us-west-2.amazonaws.com/dev';

    }
  }
  
  static Future<String> _fetchApiBaseFromGoogleDrive() async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(googleDriveDownloadUrl);

      logd('📥 Google Drive から読み込み開始: $uri ($ts)');

      final response = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
          'Pragma': 'no-cache',
          'Expires': '0',
          // ランダムヘッダを追加（CDNのキャッシュキーを変える）
          'X-Bypass-Cache': ts.toString(),
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('タイムアウト: Google Drive からの読み込みがタイムアウトしました'),
      );

      logd('📊 ステータスコード: ${response.statusCode}');
      logd('📋 レスポンスボディ長: ${response.body.length} 文字');

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('エラー: ステータスコード ${response.statusCode}');
      }
    } catch (e) {
      logd('❌ Google Drive 読み込みエラー詳細: $e');
      rethrow;
    }
  }


}
