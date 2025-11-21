import 'package:flutter/cupertino.dart';
import '../app/app_tabs.dart';
import '../screens/topic_list.dart' as tl;
import '../screens/clips_screen.dart';
import '../screens/favorites_screen.dart';

class IOSShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const IOSShell({super.key, required this.tabs});

  @override
  State<IOSShell> createState() => _IOSShellState();
}

class _IOSShellState extends State<IOSShell> {
  late final CupertinoTabController _controller;
  late final GlobalKey<ClipsScreenState> _clipsKey;
  late final GlobalKey<FavoritesScreenState> _favoritesKey;

  @override
  void initState() {
    super.initState();
    _controller = CupertinoTabController(initialIndex: 0);
    _controller.addListener(_onTabChanged);
    _clipsKey = GlobalKey<ClipsScreenState>();
    _favoritesKey = GlobalKey<FavoritesScreenState>();
  }

  void _onTabChanged() {
    final idx = _controller.index;
    final tabId = widget.tabs[idx].id;

    // ★ 履歴タブのリロード（型安全）
    if (tabId == 'tab_favorites') {
      _favoritesKey.currentState?.reloadFromOutside();
    }
    // ★ クリップタブのリロード（型安全）
    if (tabId == 'tab_clips') {
      _clipsKey.currentState?.reloadFromOutside();
    }
    // ★ 新着・人気タブのリフレッシュ（TopicListScreenState）
    if (tabId == 'tab_new' || tabId == 'tab_popular') {
      final key = widget.tabs[idx].stateKey;
      if (key is GlobalKey<tl.TopicListScreenState>) {
        key.currentState?.refreshTiles();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      controller: _controller,
      tabBar: CupertinoTabBar(
        items: [
          for (final t in widget.tabs)
            if (t.id == 'tab_favorites')
              BottomNavigationBarItem(
                icon: _RotatingIcon(
                  loadingNotifier: historyUpdatingNotifier,
                  child: Icon(t.icon),
                ),
                label: t.label,
              )
            else if (t.id == 'tab_clips')
              BottomNavigationBarItem(
                icon: _RotatingIcon(
                  loadingNotifier: clipsUpdatingNotifier,
                  child: Icon(t.icon),
                ),
                label: t.label,
              )
            else
              BottomNavigationBarItem(icon: Icon(t.icon), label: t.label),
        ],
      ),
      tabBuilder: (context, i) {
        final spec = widget.tabs[i];
        // ★ GlobalKey を各タブに渡す
        switch (spec.id) {
          case 'tab_clips':
            return CupertinoTabView(
              builder: (_) => ClipsScreen(key: _clipsKey),
            );
          case 'tab_favorites':
            return CupertinoTabView(
              builder: (_) => FavoritesScreen(key: _favoritesKey),
            );
          default:
            return CupertinoTabView(
              builder: spec.builder,
            );
        }
      },
    );
  }
}

class _RotatingIcon extends StatefulWidget {
  final ValueNotifier<bool> loadingNotifier;
  final Widget child;

  const _RotatingIcon({
    super.key,
    required this.loadingNotifier,
    required this.child,
  });

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
    widget.loadingNotifier.addListener(_onLoadingChanged);
    // 初期状態チェック
    if (widget.loadingNotifier.value) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_RotatingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadingNotifier != widget.loadingNotifier) {
      oldWidget.loadingNotifier.removeListener(_onLoadingChanged);
      widget.loadingNotifier.addListener(_onLoadingChanged);
      // 新しいnotifierの状態を反映
      _onLoadingChanged();
    }
  }

  @override
  void dispose() {
    widget.loadingNotifier.removeListener(_onLoadingChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onLoadingChanged() {
    if (widget.loadingNotifier.value) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        // 現在の回転位置から0に戻すアニメーションをして止める
        // 単に stop() だと唐突に止まるので、forward() で 1.0 まで回し切るか、
        // reset() するか。ここでは自然に止めるために animateTo を使う手もあるが、
        // シンプルに reset で止める（あるいは stop して reset）。
        // 今回は「回転し続ける」→「止まる」なので、stop() してから reset() で元の位置に戻す。
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: widget.child,
    );
  }
}
