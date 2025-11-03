import 'package:flutter/cupertino.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

/// 可変高さリストの測定用クラス（ダミー実装）
class _Measurer {
  final double fallbackHeight;
  final List<double?> _heights;
  _Measurer(int length, {this.fallbackHeight = 60.0}) : _heights = List.filled(length, null);
  void ensureCapacity(int len) {
    if (_heights.length < len) {
      _heights.length = len;
    }
  }
  void onItemSize(int i, double h) {
    if (i >= 0 && i < _heights.length) _heights[i] = h;
  }
  double? getItemHeight(int i) => (i >= 0 && i < _heights.length) ? _heights[i] : null;
}

/// サイズ測定用ラッパー（ダミー実装）
class MeasureSize extends StatelessWidget {
  final Widget child;
  final ValueChanged<Size> onChange;
  const MeasureSize({required this.child, required this.onChange, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => child;
}
