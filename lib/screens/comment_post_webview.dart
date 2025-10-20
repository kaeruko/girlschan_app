import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CommentPostWebView extends StatefulWidget {
  final int topicId;
  final String text;

  const CommentPostWebView({super.key, required this.topicId, required this.text});

  @override
  State<CommentPostWebView> createState() => _CommentPostWebViewState();
}

class _CommentPostWebViewState extends State<CommentPostWebView> {
  bool _isPosted = false;

  @override
  Widget build(BuildContext context) {
    final postData = Uint8List.fromList(utf8.encode(
      'is_post=1&is_next=1&text=${Uri.encodeComponent(widget.text)}&anonymous=匿名で投稿',
    ));

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('投稿中...'),
      ),
      child: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://girlschannel.net/make_comment/${widget.topicId}/'),
          method: 'POST',
          body: postData,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        onLoadStop: (controller, url) async {
          if (_isPosted) return; // 二重実行防止
          
          if (url != null && url.toString().contains('/topics/${widget.topicId}')) {
            _isPosted = true;
            if (mounted) {
              // 遅延実行で UI の安定性を確保
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                Navigator.pop(context, true); // 投稿完了
              }
            }
          }
        },
        onLoadError: (controller, url, code, message) {
          debugPrint('❌ WebView Load Error: $message (code: $code)');
        },
      ),
    );
  }
}
