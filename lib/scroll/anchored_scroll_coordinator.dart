import 'package:flutter/widgets.dart';
// TODO: あなたのプロジェクトのパスに合わせて import を調整
import '../utils/variable_list_measurer.dart';

class AnchoredSliverBundle {
  const AnchoredSliverBundle({required this.slivers, required this.usingCenter});
  final List<Widget> slivers;
  final bool usingCenter;
}

/// 「アンカー分割 + 局所オフセット保存/復元」をカプセル化
class AnchoredScrollCoordinator {
  AnchoredScrollCoordinator({
    Duration saveInterval = const Duration(milliseconds: 500),
  }) : _saveInterval = saveInterval;

  // 公開: UI 側で使うコントローラと center key
  final ScrollController sc = ScrollController();
  GlobalKey get centerKey => _centerKey;

  // 内部状態
  final GlobalKey _centerKey = GlobalKey();
  GlobalKey? _anchorItemKey;
  bool _restored = false;
  int _currentAnchorIndex = 0;
  DateTime? _lastSaveAt;
  final Duration _saveInterval;

  /// アンカー分割した Sliver 群を構築。
  /// - items: List<Map> で 'no' を持っている想定
  /// - savedNo: 復元対象の no
  /// - indexByNo: no -> index の逆引き
  /// - itemBuilder: index を渡すと 1 行を返すビルダー
  /// - leadingSlivers: RefreshControl などアンカーより前に置く Sliver（任意）
  AnchoredSliverBundle buildAnchoredSlivers({
    required List items,
    required int savedNo,
    required Map<int, int> indexByNo,
    required Widget Function(BuildContext ctx, int index) itemBuilder,
    List<Widget> leadingSlivers = const [],
  }) {
    final hasAnchor = savedNo > 0 && items.isNotEmpty;

    int findIndexByNo(int no) {
      final i = indexByNo[no];
      if (i != null) return i;
      // フォールバック: 線形検索
      return items.indexWhere((c) => (c['no'] as int?) == no);
    }

    final anchorIndex = hasAnchor ? findIndexByNo(savedNo) : -1;
    final usingCenter = hasAnchor && anchorIndex >= 0 && anchorIndex < items.length;

    _currentAnchorIndex = usingCenter ? anchorIndex : 0;

    // debugLabelはprivateなので、identity/hashCodeで比較するだけにする
    if (usingCenter &&
        (_anchorItemKey == null)) {
      _anchorItemKey = GlobalKey();
      _restored = false; // 新しいアンカーになったら再調整
    }

    final slivers = <Widget>[];
    slivers.addAll(leadingSlivers);

    // A: アンカーより前
    if (usingCenter) {
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
    }

    // B: アンカーを含む側（center）
    slivers.add(
      SliverList(
        key: usingCenter ? _centerKey : null,
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final idx = usingCenter ? (anchorIndex + i) : i;
            final isAnchor = usingCenter && idx == anchorIndex;
            return KeyedSubtree(
              key: isAnchor ? _anchorItemKey : ValueKey(items[idx]['no']),
              child: itemBuilder(ctx, idx),
            );
          },
          childCount: usingCenter ? (items.length - anchorIndex) : items.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
        ),
      ),
    );

    return AnchoredSliverBundle(slivers: slivers, usingCenter: usingCenter);
  }

  /// 初回 1 フレーム後に「アンカーの中の局所位置」だけ微調整
  void maybeScheduleLocalAdjust({
    required bool usingCenter,
    required double savedFraction,
  }) {
    if (!usingCenter || _restored) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _anchorItemKey?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !sc.hasClients) return;
      final frac = savedFraction.isFinite ? savedFraction.clamp(0.0, 1.0) : 0.0;
      sc.jumpTo(sc.offset + box.size.height * frac);
      _restored = true;
    });
  }

  /// スクロール中に index + fraction を保存
  /// measurer の API 名はあなたの実装に合わせてください。
  void onScrollSave({
    required VariableListMeasurer measurer,
    required void Function(int index, double fraction) save,
    required int totalCount,
  }) {
    if (!sc.hasClients) return;

    // スパム防止
    final now = DateTime.now();
    if (_lastSaveAt != null && now.difference(_lastSaveAt!) < _saveInterval) return;
    _lastSaveAt = now;

    // center 利用時は「B側先頭からの距離」→全体距離に直す
    final baseOffset = measurer.indexToOffset(_currentAnchorIndex);
    final globalOffset = sc.offset + baseOffset;

    // あなたの VariableListMeasurer に合わせて呼び分け
    final topIndex = measurer.offsetToIndex(globalOffset, totalCount);
    final rowTop   = measurer.indexToOffset(topIndex);
    final h        = (measurer.getItemHeight(topIndex) ?? measurer.fallbackHeight);
    final frac     = (h <= 0) ? 0.0 : ((globalOffset - rowTop) / h).clamp(0.0, 1.0);

    save(topIndex, frac);
  }

  void dispose() => sc.dispose();
}
