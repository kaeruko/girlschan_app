import 'package:flutter/cupertino.dart';
import '../screens/topic_list.dart';
import '../screens/favorites_screen.dart';
import '../screens/clips_screen.dart';
import '../screens/search_screen.dart';

/// タブの仕様定義
class TabSpec {
  final String id;              // 永続化や PageStorageKey用
  final String label;           // タブ表示名
  final IconData icon;          // アイコン
  final String title;           // AppBar タイトル
  final WidgetBuilder builder;  // ← タブ画面を生成するビルダー
  final GlobalKey? stateKey;    // ← State にアクセスするための GlobalKey

  const TabSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.title,
    required this.builder,
    this.stateKey,
  });
}


/// アプリ全体で使う統一されたタブ定義
/// iOS/macOS 両方で共通使用
/// 注意: GlobalKey は各タブの State にアクセスするため、定義時に生成される

// 各タブの State にアクセスするための GlobalKey（重複なし）
final _newTopicListKey = GlobalKey<TopicListScreenState>();
final _popularTopicListKey = GlobalKey<TopicListScreenState>();
final favoritesScreenStateKey = GlobalKey<FavoritesScreenState>();  // ★ 型付き
final clipsScreenStateKey = GlobalKey<ClipsScreenState>();  // ★ 型付き
final _searchKey = GlobalKey<SearchScreenState>();

// ★ 履歴更新中かどうかを通知する Notifier
final ValueNotifier<bool> historyUpdatingNotifier = ValueNotifier(false);

// ★ クリップ更新中かどうかを通知する Notifier
final ValueNotifier<bool> clipsUpdatingNotifier = ValueNotifier(false);

final List<TabSpec> kAppTabs = [
  TabSpec(
    id: 'tab_new',
    label: '新着',
    icon: CupertinoIcons.sparkles,   // or CupertinoIcons.bolt
    title: '新着トピック',
    stateKey: _newTopicListKey,
    builder: (_) => TopicListScreen(
      key: _newTopicListKey,
      sortOrder: 'new',
    ),
  ),
  TabSpec(
    id: 'tab_popular',
    label: '人気',
    icon: CupertinoIcons.flame,
    title: '人気トピック',
    stateKey: _popularTopicListKey,
    builder: (_) => TopicListScreen(
      key: _popularTopicListKey,
      sortOrder: 'popular',
    ),
  ),
  TabSpec(
    id: 'tab_favorites',
    label: '履歴',
    icon: CupertinoIcons.clock,
    title: '履歴',
    stateKey: favoritesScreenStateKey,
    builder: (_) => FavoritesScreen(
      key: favoritesScreenStateKey,
    ),
  ),
  TabSpec(
    id: 'tab_clips',
    label: 'クリップ',
    icon: CupertinoIcons.heart,
    title: 'クリップ',
    stateKey: clipsScreenStateKey,
    builder: (_) => ClipsScreen(
      key: clipsScreenStateKey,
    ),
  ),
  TabSpec(
    id: 'tab_search',
    label: '検索',
    icon: CupertinoIcons.search,
    title: '検索',
    stateKey: _searchKey,
    builder: (_) => SearchScreen(key: _searchKey),
  ),
];
