import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class CommentPostWebView extends StatelessWidget {
  final int topicId;
  final String text;

  const CommentPostWebView({super.key, required this.topicId, required this.text});

  @override
  Widget build(BuildContext context) {
    final postData = Uint8List.fromList(utf8.encode(
      'is_post=1&is_next=1&text=${Uri.encodeComponent(text)}&anonymous=匿名で投稿',
    ));

    return Scaffold(
      appBar: AppBar(title: const Text('投稿中...')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://girlschannel.net/make_comment/$topicId/'),
          method: 'POST',
          body: postData,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
        onLoadStop: (controller, url) {
          if (url != null && url.toString().contains('/topics/$topicId')) {
            Navigator.pop(context, true); // 投稿完了
          }
        },
      ),
    );
  }
}
