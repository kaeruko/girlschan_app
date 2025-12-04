import 'package:flutter/cupertino.dart';
import '../models/comment.dart';
import 'vote_bar_graph.dart';
import 'url_preview_list.dart';
import 'anchor_chips.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final CommentUserStatus userStatus;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(int no)? onAnchorTap;
  final Function(String url)? onImageTap;
  final Function(List<int> replyIds)? onRepliesTap; // ★ 追加: 返信ボタン用コールバック
  final Function(bool isPlus)? onVote;
  final bool Function(int no)? checkAnchorAvailability;
  final double fontSize;

  const CommentTile({
    super.key,
    required this.comment,
    this.userStatus = CommentUserStatus.none,
    this.onTap,
    this.onLongPress,
    this.onAnchorTap,
    this.onImageTap,
    this.onRepliesTap, // ★ 追加
    this.onVote,
    this.checkAnchorAvailability,
    this.fontSize = 15.0,
  });

  @override
  Widget build(BuildContext context) {
    final no = comment.id;
    final postedAt = comment.postedAt;
    final name = comment.name;
    final body = comment.body;
    final plus = comment.plus;
    final minus = comment.minus;
    final anchors = comment.anchors;
    final reverseAnchors = comment.reverseAnchors;
    final urls = comment.urls;
    final imageUrl = comment.imageUrl;

    final innerWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'No.$no  $name  $postedAt${comment.isLocal ? ' （ローカル）' : ''}',
              style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
            ),
            // 自分のコメントなら人アイコンのみ、それ以外でクリップされていればハートアイコンのみ
            if (userStatus == CommentUserStatus.myComment)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(CupertinoIcons.person_fill, size: 14, color: CupertinoColors.activeBlue),
              )
            else if (userStatus == CommentUserStatus.clipped)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(CupertinoIcons.heart_fill, size: 14, color: CupertinoColors.systemPink),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (anchors.isNotEmpty)
          AnchorChips(
            anchors: anchors,
            onTap: (no) => onAnchorTap?.call(no),
            isReverse: false,
            checkExists: checkAnchorAvailability,
          ),
        
        // ★ 変更: reverseAnchors (チップ表示) は削除し、下のボタンへ移動
        
        Text(body, style: TextStyle(fontSize: fontSize)),
        if (urls.isNotEmpty) UrlPreviewList(urls: urls),
        if (imageUrl != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => onImageTap?.call(comment.originalImageUrl ?? imageUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 40,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    height: 40,
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  height: 40,
                  child: Center(
                    child: Icon(CupertinoIcons.photo, size: 40, color: CupertinoColors.secondaryLabel),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        VoteBarGraph(plus: plus, minus: minus),
        const SizedBox(height: 8),
        
        // アクション行 (投票ボタンと返信ボタン)
        Row(
          children: [
            // 投票ボタン
            Row(
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () {
                    if (comment.isLocal) return;
                    onVote?.call(true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text('＋$plus', style: const TextStyle(color: CupertinoColors.systemRed)),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () {
                    if (comment.isLocal) return;
                    onVote?.call(false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text('−$minus', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
                  ),
                ),
              ],
            ),
            
            const Spacer(),

            // ★ 追加: 返信ボタン
            if (reverseAnchors.isNotEmpty)
              GestureDetector(
                onTap: () => onRepliesTap?.call(reverseAnchors),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.reply, size: 14, color: CupertinoColors.activeBlue),
                      const SizedBox(width: 4),
                      Text(
                        '返信 ${reverseAnchors.length}件',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(CupertinoIcons.chevron_right, size: 12, color: CupertinoColors.activeBlue),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );

    return Material(
      color: CupertinoColors.systemBackground, // 明示的に背景色を指定しないと透ける場合がある
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        hoverColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: innerWidget,
        ),
      ),
    );
  }
}