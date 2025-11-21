import 'package:flutter/cupertino.dart';

class VoteBarGraph extends StatelessWidget {
  final int plus;
  final int minus;

  const VoteBarGraph({
    super.key,
    required this.plus,
    required this.minus,
  });

  @override
  Widget build(BuildContext context) {
    final total = plus + minus;
    // 0件なら何も表示しない（スペースも取らない）
    if (total == 0) return const SizedBox.shrink();

    // バーの長さを計算するロジック
    const double minWidth = 30.0;
    const double maxWidth = 300.0;
    const int capVotes = 1000;

    double barWidth;
    if (total >= capVotes) {
      barWidth = maxWidth;
    } else {
      final growthRatio = total / capVotes;
      barWidth = minWidth + (maxWidth - minWidth) * growthRatio;
    }

    return SizedBox(
      width: barWidth,
      height: 20,
      child: Row(
        children: [
          // プラス（赤）部分
          if (plus > 0)
            Expanded(
              flex: plus,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFED6D74),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                ),
              ),
            ),
          // マイナス（グレー）部分
          if (minus > 0)
            Expanded(
              flex: minus,
              child: Container(
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
