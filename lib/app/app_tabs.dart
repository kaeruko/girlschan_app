import 'package:flutter/material.dart';
import '../screens/topic_list.dart';
import '../screens/favorites_screen.dart';
import '../screens/clips_screen.dart';

/// タブの仕様定義
class TabSpec {
  final String id;              // 永続化や PageStorageKey用
  final String label;           // タブ表示名
  final IconData icon;          // アイコン
  final String title;           // AppBar タイトル
  final WidgetBuilder builder;  // ← タブ画面を生成するビルダー

  const TabSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.title,
    required this.builder,
  });
}

/// アプリ全体で使う統一されたタブ定義
/// iOS/macOS 両方で共通使用
final List<TabSpec> kAppTabs = [
  TabSpec(
    id: 'tab_new',
    label: '新着',
    icon: Icons.fiber_new,
    title: '新着トピック',
    builder: (_) => const TopicListScreen(
      key: PageStorageKey('tab_new'),
      sortOrder: 'new',
    ),
  ),
  TabSpec(
    id: 'tab_popular',
    label: '人気',
    icon: Icons.trending_up,
    title: '人気トピック',
    builder: (_) => const TopicListScreen(
      key: PageStorageKey('tab_popular'),
      sortOrder: 'popular',
    ),
  ),
  TabSpec(
    id: 'tab_favorites',
    label: '履歴',
    icon: Icons.bookmark,
    title: '履歴',
    builder: (_) => const FavoritesScreen(
      key: PageStorageKey('tab_favorites'),
    ),
  ),
  TabSpec(
    id: 'tab_clips',
    label: 'クリップ',
    icon: Icons.favorite,
    title: 'クリップ',
    builder: (_) => const ClipsScreen(
      key: PageStorageKey('tab_clips'),
    ),
  ),
];
