import 'package:flutter/cupertino.dart';
import 'vote_bar_graph.dart';
import 'url_preview_list.dart';
import 'anchor_chips.dart';

class CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isClipped;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(int no)? onAnchorTap;
  final Function(String url)? onImageTap;
  final Function(bool isPlus)? onVote;
  final bool Function(int no)? checkAnchorAvailability;

  const CommentTile({
    super.key,
    required this.comment,
    this.isClipped = false,
    this.onTap,
    this.onLongPress,
    this.onAnchorTap,
    this.onImageTap,
    this.onVote,
    this.checkAnchorAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final no = (comment['no'] as int?) ?? -1;
    final postedAt = comment['posted_at'] ?? '';
    final name = comment['name'] ?? '';
    final body = comment['body'] ?? '';
    final plus = comment['plus'] ?? 0;
    final minus = comment['minus'] ?? 0;
    final anchors = List<int>.from(comment['anchors'] ?? []);
    final reverseAnchors = List<int>.from(comment['reverse_anchors'] ?? []);
    final urls = (comment['urls'] as List?) ?? [];
    final imageUrl = comment['image_url'] as String?;

    final innerWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No.$no  $name  $postedAt${comment['isLocal'] == true ? ' （ローカル）' : ''}',
          style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
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
            onTap: () => onImageTap?.call(imageUrl),
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
                if (comment['isLocal'] == true) return;
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
                if (comment['isLocal'] == true) return;
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
        // key: no > 0 ? _vm.keyForCommentNo(no) : null, // Key handling should be done by parent if needed, or passed in.
        // The parent (TopicDetailScreen) uses the key for scrolling. 
        // We should probably allow passing a Key to the widget itself, or let the parent wrap it.
        // But the original code put the key on the Container.
        // If I put the key on CommentTile, it's on the widget.
        // The parent wraps CommentTile in MeasureSize.
        // The original code: Container(key: ...).
        // If I pass the key to CommentTile constructor, it applies to CommentTile.
        // If CommentTile builds a Container, that Container doesn't necessarily need the key if CommentTile has it?
        // Wait, Scrollable.ensureVisible(ctx) uses the context of the key.
        // If the key is on CommentTile, ctx refers to CommentTile.
        // If the key is on Container, ctx refers to Container.
        // It should be fine if it's on CommentTile.
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: innerWidget,
      ),
    );
  }






}
