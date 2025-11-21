import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/comment.dart';

class UrlPreviewList extends StatelessWidget {
  final List<dynamic> urls;

  const UrlPreviewList({
    super.key,
    required this.urls,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: urls.map((urlData) => _buildUrlTile(context, urlData)).toList(),
      ),
    );
  }

  Widget _buildUrlTile(BuildContext context, dynamic urlData) {
    String url = '';
    String title = '';
    String? description;
    String? thumbnail;

    // Map型とCommentUrl型の両方に対応
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
            // サムネイル画像
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
            
            // テキスト情報
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
  }
}
