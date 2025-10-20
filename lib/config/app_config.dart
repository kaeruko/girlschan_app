import 'package:http/http.dart' as http;

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
    } catch (e) {
      print('エラー: Google Drive から apiBase の読み込みに失敗しました: $e');
      // フォールバック値を設定
      apiBase = 'https://evhch6a2hc.execute-api.us-west-2.amazonaws.com/dev';

    }
  }
  
  /// Google Drive からテキストファイルを読み込み
  static Future<String> _fetchApiBaseFromGoogleDrive() async {
    try {
      print('📥 Google Drive から読み込み開始: $googleDriveDownloadUrl');
      
      final response = await http.get(
        Uri.parse(googleDriveDownloadUrl),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('タイムアウト: Google Drive からの読み込みがタイムアウトしました'),
      );
      
      print('📊 ステータスコード: ${response.statusCode}');
      print('📋 レスポンスボディ長: ${response.body.length} 文字');
      print('📋 レスポンスボディ: ${response.body}');
      
      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('エラー: ステータスコード ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Google Drive 読み込みエラー詳細: $e');
      print('❌ エラータイプ: ${e.runtimeType}');
      rethrow;
    }
  }
}
