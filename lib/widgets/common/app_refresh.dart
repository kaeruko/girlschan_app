import 'package:flutter/cupertino.dart';

/// リフレッシュコールバック型
typedef RefreshFn = Future<void> Function();

/// Material の `RefreshIndicator` の Cupertino 版置換。
/// 
/// `CupertinoSliverRefreshControl` を標準化。
/// 基本は Sliver 構成に寄せるのが一番きれい。
/// 
/// 使用例：
/// ```dart
/// AppRefresh(
///   onRefresh: _reloadTopics,
///   slivers: [
///     AppSliverList(
///       itemCount: topics.length,
///       itemBuilder: (ctx, i) => TopicTile(topic: topics[i]),
///     ),
///   ],
/// )
/// ```
class AppRefresh extends StatelessWidget {
  /// リフレッシュ時のコールバック
  final RefreshFn onRefresh;

  /// 表示する Sliver ウィジェットリスト
  /// （最初に CupertinoSliverRefreshControl が自動挿入される）
  final List<Widget> slivers;

  const AppRefresh({
    super.key,
    required this.onRefresh,
    required this.slivers,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
      ],
    );
  }
}

/// 既存の `ListView.builder` 相当を Sliver に寄せる簡易ヘルパ
/// 
/// 使用例：
/// ```dart
/// AppSliverList(
///   itemCount: items.length,
///   itemBuilder: (ctx, i) => ItemWidget(item: items[i]),
/// )
/// ```
class AppSliverList extends StatelessWidget {
  /// リストアイテムの個数
  final int itemCount;

  /// リストアイテムを構築するビルダー関数
  final Widget Function(BuildContext, int) itemBuilder;

  const AppSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Sliver に簡単には寄せられない場合用の暫定ラッパ
/// （将来段階的に Sliver 化する際の一時措置）
class AppRefreshLazy extends StatefulWidget {
  final RefreshFn onRefresh;
  final Widget child; // RefreshIndicator を含まない child
  final Duration delay;

  const AppRefreshLazy({
    super.key,
    required this.onRefresh,
    required this.child,
    this.delay = const Duration(milliseconds: 200),
  });

  @override
  State<AppRefreshLazy> createState() => _AppRefreshLazyState();
}

class _AppRefreshLazyState extends State<AppRefreshLazy> {
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cupertino 版 RefreshIndicator の代わりに
    // 画面上にリフレッシュボタンを配置するか、
    // あるいは将来的に Sliver 化するまでの暫定措置
    return widget.child;
  }
}
