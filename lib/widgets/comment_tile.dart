import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/comment.dart';
import '../screens/image_viewer_page.dart';

class CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isClipped;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Function(int no) onAnchorTap;
  final Function(bool isPlus) onVote;

  const CommentTile({
    super.key,
    required this.comment,
    required this.isClipped,
    required this.onTap,
    required this.onLongPress,
    required this.onAnchorTap,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final no = (comment['no'] as int?) ?? -1;
    final posted_at = comment['posted_at'] ?? '';
    final name = comment['name'] ?? '';
    final body = comment['body'] ?? '';
    final plus = comment['plus'] ?? 0;
    final minus = comment['minus'] ?? 0;
    final anchors = List<int>.from(comment['anchors'] ?? []);
    final reverseAnchors = List<int>.from(comment['reverse_anchors'] ?? []);
    final urls = (comment['urls'] as List?) ?? [];

    final innerWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No.$no  $name  $posted_at${comment['isLocal'] == true ? ' （ローカル）' : ''}',
            style: const TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel)),
        const SizedBox(height: 8),
        if (anchors.isNotEmpty) _buildAnchorText(anchors),
        if (reverseAnchors.isNotEmpty) _buildReverseAnchorText(reverseAnchors),
        Text(body, style: const TextStyle(fontSize: 15)),
        if (urls.isNotEmpty) _buildUrlsWidget(context, urls),
        if (comment['image_url'] != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ImageViewerPage(url: comment['image_url']),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                comment['image_url'],
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
        _buildPlusMinusGraph(plus, minus),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => onVote(true),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('＋$plus', style: const TextStyle(color: CupertinoColors.systemRed)),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => onVote(false),
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
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: innerWidget,
      ),
    );
  }

  Widget _buildAnchorText(List<int> anchors) {
    if (anchors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Wrap(
            spacing: 4,
            children: anchors.map((no) {
              return GestureDetector(
                onTap: () => onAnchorTap(no),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBlue.withOpacity(0.1),
                    border: Border.all(
                      color: CupertinoColors.systemBlue,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '>>$no',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReverseAnchorText(List<int> reverseAnchors) {
    if (reverseAnchors.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 4,
              children: reverseAnchors.take(5).map((no) {
                return GestureDetector(
                  onTap: () => onAnchorTap(no),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemOrange.withOpacity(0.1),
                      border: Border.all(
                        color: CupertinoColors.systemOrange,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '<<$no',
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (reverseAnchors.length > 5)
            Text(
              ' +${reverseAnchors.length - 5}件',
              style: const TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel),
            ),
        ],
      ),
    );
  }

  Widget _buildUrlsWidget(BuildContext context, List<dynamic> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: urls.map((urlData) {
          String url = '';
          String title = '';
          String? description;
          String? thumbnail;

          if (urlData is Map<String, dynamic>) {
            url = urlData['url'] ?? '';
            title = urlData['title'] ?? '';
            description = urlData['description'];
            thumbnail = urlData['thumbnail'];
          } else if (urlData is CommentUrl) {
            url = urlData.url;
            title = urlData.title;
            description = urlData.description;
            thumbnail = urlData.thumbnail;
          }

          if (url.isEmpty) return const SizedBox.shrink();

          return GestureDetector(
            onTap: () async {
              final Uri uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CupertinoColors.systemGrey4),
              ),
              child: Row(
                children: [
                  if (thumbnail != null && thumbnail.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Image.network(
                        thumbnail,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 80),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isNotEmpty ? title : url,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: CupertinoColors.activeBlue,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (description != null && description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: CupertinoColors.secondaryLabel,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            url,
                            style: const TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.tertiaryLabel,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlusMinusGraph(int plus, int minus) {
    final total = plus + minus;
    if (total == 0) return const SizedBox.shrink();

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
      child: Row(
        children: [
          if (plus > 0)
            Expanded(
              flex: plus,
              child: Container(
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFED6D74),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
                ),
                alignment: Alignment.center,
              ),
            ),
          if (minus > 0)
            Expanded(
              flex: minus,
              child: Container(
                height: 20,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                ),
                alignment: Alignment.center,
              ),
            ),
        ],
      ),
    );
  }
}
