import 'package:flutter/material.dart';
import '../screens/new_list.dart';
import '../screens/topic_list.dart';
import '../screens/favorites_screen.dart';
import '../screens/clips_screen.dart';

/// タブの仕様定義
class TabSpec {
  final String id;              // 永続化や PageStorageKey用
  final String label;           // タブ表示名
  final IconData icon;          // アイコン（Material Icons）
  final String title;           // AppBar タイトル
  final Widget widget;          // タブのルート画面

  const TabSpec({
    required this.id,
    required this.label,
    required this.icon,
    required this.title,
    required this.widget,
  });
}

/// PageStorageKey でスクロール位置を維持
/// 各タブの画面を PageStorage でラップ
Widget _wrapWithStorage(Widget child, String id) =>
    PageStorage(
      key: PageStorageKey<String>(id),
      bucket: PageStorageBucket(),
      child: child,
    );

/// アプリ全体で使う統一されたタブ定義
/// iOS/Android 両方で共通使用
final List<TabSpec> kAppTabs = [
  TabSpec(
    id: 'tab_new',
    label: '新着',
    icon: Icons.fiber_new,
    title: '新着トピック',
    widget: _wrapWithStorage(const NewListScreen(), 'tab_new'),
  ),
  TabSpec(
    id: 'tab_popular',
    label: '人気',
    icon: Icons.trending_up,
    title: '人気トピック',
    widget: _wrapWithStorage(const TopicListScreen(), 'tab_popular'),
  ),
  TabSpec(
    id: 'tab_favorites',
    label: '履歴',
    icon: Icons.bookmark,
    title: '履歴',
    widget: _wrapWithStorage(const FavoritesScreen(), 'tab_favorites'),
  ),
  TabSpec(
    id: 'tab_clips',
    label: 'クリップ',
    icon: Icons.favorite,
    title: 'クリップ',
    widget: _wrapWithStorage(const ClipsScreen(), 'tab_clips'),
  ),
];
