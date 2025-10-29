import 'package:flutter/widgets.dart';

class VariableListMeasurer {
  VariableListMeasurer({this.fallbackHeight = 150.0});

  final double fallbackHeight;

  List<double> _itemHeights = [];
  List<double> _prefix = [0.0];
  bool _dirty = true;

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

  void onItemSize(int index, double height, {ScrollController? sc}) {
    if (index < 0 || index >= _itemHeights.length) return;
    if ((height - _itemHeights[index]).abs() < 0.5) return;
    _itemHeights[index] = height;
    _dirty = true;

    if (_restoreTargetIndex != null && sc != null && sc.hasClients && index <= _restoreTargetIndex!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final off = indexToOffset(_restoreTargetIndex!);
        final max = sc.position.maxScrollExtent;
        sc.jumpTo(off.clamp(0.0, max));
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
    int lo = 0, hi = _prefix.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (_prefix[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo.clamp(0, (itemCount - 1).clamp(0, 1 << 30));
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
