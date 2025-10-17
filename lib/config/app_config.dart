class AppConfig {
  // ==== 接続先API ====
  static const String apiBase = 'http://192.168.40.171:5050';

  // ==== キャッシュ関連 ====
  static const String cacheDirName = 'cache';
  static const String favoritesFile = 'favorites.json';
  static const String favoritesDataFile = 'favorites_data.json';

  // ==== ページング ====
  static const int defaultLimit = 100;

  // ==== テーマ・UI ====
  static const String appTitle = 'TalkBoard';
  static const double cornerRadius = 12.0;
}
