import 'package:flutter/cupertino.dart';

class AnchorChips extends StatelessWidget {
  final List<int> anchors;
  final Function(int no, Offset pos) onTap;
  final bool isReverse; // trueなら逆アンカー(<<)、falseなら通常(>>)
  
  /// 指定した番号のコメントが存在するかチェックする関数（オプション）
  /// 存在しない場合はグレーアウト表示にするために使う
  final bool Function(int no)? checkExists;

  const AnchorChips({
    super.key,
    required this.anchors,
    required this.onTap,
    this.isReverse = false,
    this.checkExists,
  });

  @override
  Widget build(BuildContext context) {
    if (anchors.isEmpty) return const SizedBox.shrink();

    // --- 色と記号の設定 ---
    final color = isReverse ? CupertinoColors.systemOrange : CupertinoColors.systemBlue;
    final prefix = isReverse ? '<<' : '>>';

    // --- 表示するリストの生成（逆アンカーは最大30件） ---
    final displayList = (isReverse && anchors.length > 30)
        ? anchors.take(30).toList()
        : anchors;
    
    final remainder = anchors.length - displayList.length;

    // --- チップ部分の作成（共通ロジック） ---
    Widget buildWrap() {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isReverse ? WrapAlignment.start : WrapAlignment.end,
        children: displayList.map((no) {
          // 存在チェック（関数が渡されていなければ常にtrue扱い）
          final exists = checkExists?.call(no) ?? true;
          
          return GestureDetector(
            onTapDown: (details) => onTap(no, details.globalPosition),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: exists 
                    ? color.withValues(alpha: 0.1) 
                    : CupertinoColors.systemGrey.withValues(alpha: 0.1),
                border: Border.all(
                  color: exists ? color : CupertinoColors.systemGrey3,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$prefix$no',
                style: TextStyle(
                  fontSize: 12,
                  color: exists ? color : CupertinoColors.secondaryLabel,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: isReverse
          ? Row(
              children: [
                Expanded(child: buildWrap()),
                if (remainder > 0)
                  Text(
                    ' +$remainder件',
                    style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
                  ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 通常アンカーは折り返しが増えても右寄せのままWrapさせるため、
                // Expandedは使わず、Flexibleまたはそのまま配置
                Flexible(child: buildWrap()),
              ],
            ),
    );
  }
}
