import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../app/app_tabs.dart';
import '../screens/topic_list.dart' as tl;
import '../screens/clips_screen.dart';
import '../screens/favorites_screen.dart';
import '../utils/platform_helper.dart';

/// iOSとAndroidで共用するモバイル向けボトムタブシェル。
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
              BottomNavigationBarItem(
                icon: Icon(t.icon),
                label: PlatformHelper.isAndroid && t.id == 'tab_annotation'
                    ? '注釈'
                    : t.label,
              ),
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
            return CupertinoTabView(builder: spec.builder);
        }
      },
    );
  }
}

class _RotatingIcon extends StatefulWidget {
  final ValueNotifier<bool> loadingNotifier;
  final Widget child;

  const _RotatingIcon({required this.loadingNotifier, required this.child});

  @override
  State<_RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<_RotatingIcon> {
  Timer? _timer;
  double _angle = 0.0;

  @override
  void initState() {
    super.initState();
    widget.loadingNotifier.addListener(_onLoadingChanged);
    if (widget.loadingNotifier.value) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(_RotatingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadingNotifier != widget.loadingNotifier) {
      oldWidget.loadingNotifier.removeListener(_onLoadingChanged);
      widget.loadingNotifier.addListener(_onLoadingChanged);
      _onLoadingChanged();
    }
  }

  @override
  void dispose() {
    widget.loadingNotifier.removeListener(_onLoadingChanged);
    _stopTimer();
    super.dispose();
  }

  void _onLoadingChanged() {
    if (widget.loadingNotifier.value) {
      _startTimer();
    } else {
      _stopTimer();
      // 停止時は角度をリセット
      setState(() {
        _angle = 0.0;
      });
    }
  }

  void _startTimer() {
    if (_timer != null) return;
    // 16msごとに約1度回転させる (1周約5.7秒)
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _angle += 0.02; // ラジアン加算
        if (_angle > 2 * 3.1415926535) {
          _angle -= 2 * 3.1415926535;
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(angle: _angle, child: widget.child);
  }
}
