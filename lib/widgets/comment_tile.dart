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
  final Function(bool isPlus)? onVote;
  final bool Function(int no)? checkAnchorAvailability;

  const CommentTile({
    super.key,
    required this.comment,
    this.userStatus = CommentUserStatus.none,
    this.onTap,
    this.onLongPress,
    this.onAnchorTap,
    this.onImageTap,
    this.onVote,
    this.checkAnchorAvailability,
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
        if (reverseAnchors.isNotEmpty)
          AnchorChips(
            anchors: reverseAnchors,
            onTap: (no) => onAnchorTap?.call(no),
            isReverse: true,
            checkExists: checkAnchorAvailability,
          ),
        Text(body, style: const TextStyle(fontSize: 15)),
        if (urls.isNotEmpty) UrlPreviewList(urls: urls),
        if (imageUrl != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => onImageTap?.call(imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
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
        ],
        const SizedBox(height: 6),
        VoteBarGraph(plus: plus, minus: minus),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (comment.isLocal) return;
                onVote?.call(true);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('＋$plus', style: const TextStyle(color: CupertinoColors.systemRed)),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                if (comment.isLocal) return;
                onVote?.call(false);
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('−$minus', style: const TextStyle(color: CupertinoColors.secondaryLabel)),
              ),
            ),
          ],
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: innerWidget,
      ),
    );
  }
}
