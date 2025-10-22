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

  const AppSpinner({
    super.key,
    this.size = 16,
    this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CupertinoActivityIndicator(
        radius: 8, // size に応じて調整可能
      ),
    );
  }
}
