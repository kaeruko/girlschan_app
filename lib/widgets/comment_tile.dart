import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'; // ★これを追加
import 'package:url_launcher/url_launcher.dart';
import '../models/comment.dart';
import 'vote_bar_graph.dart';
import 'url_preview_list.dart';
import 'anchor_chips.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final CommentUserStatus userStatus;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(int no, Offset? pos)? onAnchorTap;
  final Function(String url)? onImageTap;
  final Function(List<int> replyIds)? onRepliesTap; // ★ 追加: 返信ボタン用コールバック
  final Function(bool isPlus)? onVote;
  final bool Function(int no)? checkAnchorAvailability;
  final double fontSize;
  final bool highlighted; // ★ 追加: ハイライト表示用

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
    this.highlighted = false, // ★ 追加
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
            onTap: (no, pos) => onAnchorTap?.call(no, pos),
            isReverse: false,
            checkExists: checkAnchorAvailability,
          ),
        
        // ★ 変更: reverseAnchors (チップ表示) は削除し、下のボタンへ移動
        
        _LinkText(text: body, fontSize: fontSize),
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
                    color: CupertinoColors.activeBlue.withValues(alpha: 0.1),
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
      color: Colors.transparent, // 親の背景色を透過させる
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        hoverColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        mouseCursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: highlighted ? Colors.yellow.withValues(alpha: 0.3) : null, // ★ ハイライト時の背景色
            border: const Border(bottom: BorderSide(color: CupertinoColors.separator, width: 0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: innerWidget,
        ),
      ),
    );
  }
}

final _urlPattern = RegExp(r'https?://[^\s　]+');

class _LinkText extends StatefulWidget {
  final String text;
  final double fontSize;

  const _LinkText({required this.text, required this.fontSize});

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _buildSpans(String text, double fontSize) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _urlPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        };
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(
          color: CupertinoColors.activeBlue,
          decoration: TextDecoration.underline,
        ),
        recognizer: recognizer,
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans(widget.text, widget.fontSize);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: widget.fontSize,
          color: CupertinoColors.label.resolveFrom(context),
        ),
        children: spans,
      ),
    );
  }
}