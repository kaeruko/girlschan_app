import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter/widgets.dart';
import '../utils/variable_list_measurer.dart';

class AnchoredScrollBundle {
  AnchoredScrollBundle({
    required this.slivers,
    required this.usingCenter,
    this.centerKey,
  });
  final List<Widget> slivers;
  final bool usingCenter;
  final Key? centerKey; // usingCenter=true のときだけ非null
}

class AnchoredScrollCoordinator {
  AnchoredScrollCoordinator({
    ScrollController? controller,
    Duration saveInterval = const Duration(milliseconds: 500),
  })  : sc = controller ?? ScrollController(),
        _ownsController = controller == null,
        _saveInterval = saveInterval;

  final ScrollController sc;
  final bool _ownsController;

  // centerはダミーBoxを必ず1個だけ挟む
  final GlobalKey _centerKey = GlobalKey();
  GlobalKey get centerKey => _centerKey;

  GlobalKey? _anchorItemKey;
  bool _restored = false;
  int _currentAnchorIndex = 0;
  DateTime? _lastSaveAt;
  final Duration _saveInterval;

  AnchoredScrollBundle buildAnchoredSlivers({
    required List items,
    required int savedNo,
    required int Function(int no) indexByNo,
    required Widget Function(BuildContext ctx, int index) itemBuilder,
    List<Widget> leadingSlivers = const [],
  }) {
    final hasAnchor = savedNo > 0 && items.isNotEmpty;

    int findIndexByNo(int no) {
      final idx = indexByNo(no);
      if (idx >= 0 && idx < items.length) return idx;
      return items.indexWhere((c) => (c['no'] as int?) == no);
    }

    final anchorIndex = hasAnchor ? findIndexByNo(savedNo) : -1;
    final usingCenter = hasAnchor && anchorIndex >= 0 && anchorIndex < items.length;
    _currentAnchorIndex = usingCenter ? anchorIndex : 0;

    if (usingCenter && _anchorItemKey == null) {
      _anchorItemKey = GlobalKey();
      _restored = false;
    }

    final slivers = <Widget>[];
    slivers.addAll(leadingSlivers);

    if (!usingCenter) {
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => itemBuilder(ctx, i),
            childCount: items.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            addSemanticIndexes: false,
          ),
        ),
      );
      return AnchoredScrollBundle(slivers: slivers, usingCenter: false, centerKey: null);
    }

    // A 側（アンカーより前）
    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => itemBuilder(ctx, i),
          childCount: anchorIndex,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
        ),
      ),
    );

    // B 側（アンカー含む後半）← ★ここに center key を付ける
    slivers.add(
      SliverList(
        key: _centerKey, // ← これを center: に渡す
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final idx = anchorIndex + i;
            final isAnchor = idx == anchorIndex;
            return KeyedSubtree(
              key: isAnchor ? _anchorItemKey : ValueKey(items[idx]['no']),
              child: itemBuilder(ctx, idx),
            );
          },
          childCount: items.length - anchorIndex,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
        ),
      ),
    );

    return AnchoredScrollBundle(
      slivers: slivers,
      usingCenter: true,
      centerKey: _centerKey,
    );
  }



  // 1フレーム後に行内フラクションだけ微調整
  void maybeScheduleLocalAdjust({
    required bool usingCenter,
    required double savedFraction,
  }) {
    if (!usingCenter || _restored) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _anchorItemKey?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !sc.hasClients) return;
      final frac = savedFraction.isFinite ? savedFraction.clamp(0.0, 1.0) : 0.0;
      final before = sc.offset;
      final jump = box.size.height * frac;
      sc.jumpTo(before + jump);
      // debug
      // ignore: avoid_print
      print('[maybeScheduleLocalAdjust] anchorIndex=$_currentAnchorIndex, '
            'frac=$frac, before=$before, jump=$jump, after=${before + jump}');
      _restored = true;
    });
  }

  // スクロール位置保存（index+fraction）
  void onScrollSave({
    required VariableListMeasurer measurer,
    required void Function(int index, double fraction) save,
    required int totalCount,
  }) {
    if (!sc.hasClients) return;
    final now = DateTime.now();
    if (_lastSaveAt != null && now.difference(_lastSaveAt!) < _saveInterval) return;
    _lastSaveAt = now;

    // B側先頭からの距離 -> 全体オフセットに直す
    final baseOffset = measurer.indexToOffset(_currentAnchorIndex);
    final globalOffset = sc.offset + baseOffset;

    final topIndex = measurer.offsetToIndex(globalOffset, totalCount);
    final rowTop   = measurer.indexToOffset(topIndex);
    final h        = (measurer.getItemHeight(topIndex) ?? measurer.fallbackHeight);
    final frac     = (h <= 0) ? 0.0 : ((globalOffset - rowTop) / h).clamp(0.0, 1.0);

    save(topIndex, frac);
  }

  void dispose() {
    if (_ownsController) sc.dispose();
  }
}
