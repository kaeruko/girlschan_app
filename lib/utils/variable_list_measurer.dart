import 'package:flutter/widgets.dart';

class VariableListMeasurer {
  /// 指定インデックスの高さを取得（範囲外ならnull）
  double? getItemHeight(int idx) {
    if (idx < 0 || idx >= _itemHeights.length) return null;
    return _itemHeights[idx];
  }
  /// 指定インデックスが計測済みかどうか
  bool isMeasured(int idx) {
    if (idx < 0 || idx >= _itemHeights.length) return false;
    return _itemHeights[idx] != fallbackHeight;
  }
  VariableListMeasurer({this.fallbackHeight = 150.0});

  final double fallbackHeight;

  List<double> _itemHeights = [];
  List<double> _prefix = [0.0];
  bool _dirty = true;
  
  /// ★ 復元後など、継続的にサイズ計測が必要な場合に true にする
  bool needsUpdate = false;

  final Map<int, GlobalKey> _itemKeys = {}; // commentNo -> key
  int? _restoreTargetIndex;

  void ensureCapacity(int length) {
    if (_itemHeights.length < length) {
      _itemHeights.addAll(List.filled(length - _itemHeights.length, fallbackHeight));
    } else if (_itemHeights.length > length) {
      _itemHeights = _itemHeights.sublist(0, length);
    }
    if (_prefix.length != length + 1) {
      _prefix = List.filled(length + 1, 0.0);
      _dirty = true;
    }
  }

  // リストのある行の実測高さが分かった瞬間に、復元ターゲット位置までスクロールを追従させるためのフック
  void onItemSize(int index, double height, {ScrollController? sc}) {
    if (index < 0 || index >= _itemHeights.length) return;
    if ((height - _itemHeights[index]).abs() < 0.5) return;
    _itemHeights[index] = height;
    _dirty = true;

    // ★ スナップショットを取る
    final target = _restoreTargetIndex;

    if (target != null && sc != null && sc.hasClients && index <= target) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // ★ 実行時にも再チェック
        if (target == null) return;
        if (!sc.hasClients) return;
        final off = indexToOffset(target);
        final max = sc.position.maxScrollExtent;
        final clamped = off.clamp(0.0, max);
        // try/catchでさらに安全にしてもOK
        sc.jumpTo(clamped);
      });
    }
  }

  void _rebuildPrefixIfNeeded() {
    if (!_dirty) return;
    double acc = 0.0;
    _prefix[0] = 0.0;
    for (int i = 0; i < _itemHeights.length; i++) {
      acc += _itemHeights[i];
      _prefix[i + 1] = acc;
    }
    _dirty = false;
  }

  double indexToOffset(int index) {
    _rebuildPrefixIfNeeded();
    if (index <= 0) return 0.0;
    if (index >= _prefix.length - 1) return _prefix.last;
    return _prefix[index];
  }

  int offsetToIndex(double offset, int itemCount) {
    _rebuildPrefixIfNeeded();
    if (itemCount <= 0) return 0;
    int lo = 0, hi = _prefix.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_prefix[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    final maxIdx = itemCount - 1;
    if (lo < 0) return 0;
    if (lo > maxIdx) return maxIdx;
    return lo;
  }

  GlobalKey keyForNo(int no) => _itemKeys.putIfAbsent(no, () => GlobalKey(debugLabel: 'cno_$no'));

  Future<void> ensureVisibleOnce(int targetNo) async {
    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      final ctx = keyForNo(targetNo).currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, alignment: 0.0, duration: const Duration(milliseconds: 1));
        break;
      }
    }
  }

  void markRestoreTargetIndex(int? idx) => _restoreTargetIndex = idx;
}
