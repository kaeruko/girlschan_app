import 'package:flutter/cupertino.dart';
import 'comment_post_webview.dart';

class CommentComposePage extends StatefulWidget {
  final int topicId;
  final String title;
  final String? initialText;

  const CommentComposePage({
    super.key,
    required this.topicId,
    required this.title,
    this.initialText,
  });

  @override
  State<CommentComposePage> createState() => _CommentComposePageState();
}

class _CommentComposePageState extends State<CommentComposePage> {
  late final TextEditingController _ctrl;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _goToConfirm() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _posting) return;

    setState(() => _posting = true);

    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => CommentPostWebView(
          topicId: widget.topicId,
          title: widget.title,
          postPageUrl:
              Uri.parse('https://girlschannel.net/topics/${widget.topicId}'),
          initialText: text, // ★ ここで渡す
        ),
      ),
    );

    setState(() => _posting = false);

    // WebView 側で投稿完了したら pop(true) する想定
    if (result == true) {
      Navigator.of(context).pop(text); // 一個前の画面に「投稿したよ」と返す（テキストも渡す）
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('コメント入力'),
        previousPageTitle: '戻る',
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _posting ? null : _goToConfirm,
          child: _posting
              ? const CupertinoActivityIndicator()
              : const Icon(CupertinoIcons.paperplane),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CupertinoTextField(
            controller: _ctrl,
            maxLines: null,
            placeholder: 'コメントを書く',
          ),
        ),
      ),
    );
  }
}