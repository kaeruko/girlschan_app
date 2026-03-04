import 'package:flutter/cupertino.dart';

/// Material の `CircularProgressIndicator` の完全置換。
/// 
/// どの画面でも同じ見た目（CupertinoActivityIndicator）に固定。
/// iOS/macOS で一貫した回転アニメーション。
class AppSpinner extends StatelessWidget {
  /// スピナーのサイズ（直径）
  final double size;
  
  /// 余地：将来デザイン変えるとき用
  final double? stroke;

  /// 「読み込み中...」ラベルを表示するか
  final bool showLabel;

  const AppSpinner({
    super.key,
    this.size = 16,
    this.stroke,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CupertinoActivityIndicator(
        radius: size / 2, // size に連動して調整
      ),
    );

    if (!showLabel) return indicator;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(height: 12),
        const Text(
          '読み込み中...',
          style: TextStyle(
            fontSize: 13,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}
