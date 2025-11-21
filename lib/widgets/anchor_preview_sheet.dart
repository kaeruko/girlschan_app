import 'package:flutter/cupertino.dart';


import '../models/comment.dart';

class AnchorPreviewSheet extends StatelessWidget {
  final Comment comment;
  final bool isClipped;
  
  // 親から機能を借りるためのコールバック
  final Function(int no) onAnchorTap;
  final Function(String url) onImageTap;
  final VoidCallback onClipToggle;
  final Function(bool isPlus)? onVote; // true: plus, false: minus

  const AnchorPreviewSheet({
    super.key,
    required this.comment,
    required this.isClipped,
    required this.onAnchorTap,
    required this.onImageTap,
    required this.onClipToggle,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    // データ取り出し（安全に）
    final no = comment.id.toString();
    final body = comment.body;
    final postedAt = comment.postedAt;
    final imgUrl = comment.imageUrl;
    final anchors = comment.anchors;
    final revAnchors = comment.reverseAnchors;
    final plus = comment.plus;
    final minus = comment.minus;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // --- ヘッダー ---
            _buildHeader(context, no, postedAt),
            
            // --- スクロール可能な本文 ---
            Expanded(
              child: CupertinoScrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (anchors.isNotEmpty) _buildAnchorChips(anchors, isReverse: false),
                      if (revAnchors.isNotEmpty) _buildAnchorChips(revAnchors, isReverse: true),
                      
                      Text(body, style: const TextStyle(fontSize: 15)),
                      
                      if (imgUrl != null && imgUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: GestureDetector(
                            onTap: () => onImageTap(imgUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imgUrl,
                                height: 200,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(
                                    height: 200,
                                    child: Center(child: CupertinoActivityIndicator()),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => const SizedBox(
                                  height: 200,
                                  child: Center(
                                    child: Icon(CupertinoIcons.photo, size: 40, color: CupertinoColors.secondaryLabel),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),
                      
                      // --- リアクション ---
                      _buildReactionRow(context, plus, minus),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ヘッダー部分
  Widget _buildHeader(BuildContext context, String no, String date) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CupertinoColors.separator)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('No.$no  $date',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: CupertinoColors.secondaryLabel)),
          CupertinoButton(
            padding: const EdgeInsets.all(4),
            onPressed: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.xmark, size: 20),
          ),
        ],
      ),
    );
  }

  // アンカーチップ（通常・逆アンカー共通化）
  Widget _buildAnchorChips(List<int> list, {required bool isReverse}) {
    final color = isReverse ? CupertinoColors.systemOrange : CupertinoColors.systemBlue;
    final prefix = isReverse ? '<<' : '>>';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isReverse ? WrapAlignment.start : WrapAlignment.end,
        children: list.map((n) {
          return GestureDetector(
            onTap: () => onAnchorTap(n),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                border: Border.all(color: color, width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$prefix$n',
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // リアクション行
  Widget _buildReactionRow(BuildContext context, int plus, int minus) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('＋$plus', style: const TextStyle(color: Color(0xFFED6D74))),
            const SizedBox(width: 16),
            Text('−$minus', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
          ],
        ),
        CupertinoButton(
          padding: const EdgeInsets.all(4),
          onPressed: () {
            Navigator.pop(context); // クリップ操作後に閉じる場合
            onClipToggle();
          },
          child: Icon(
            isClipped ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
            color: isClipped ? CupertinoColors.systemRed : CupertinoColors.secondaryLabel,
            size: 22,
          ),
        ),
      ],
    );
  }
}
