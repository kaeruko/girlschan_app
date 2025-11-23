import 'package:flutter/cupertino.dart';


class TopicMenuSheet extends StatelessWidget {
  final VoidCallback onJump;
  final VoidCallback onReload;
  final VoidCallback onPost;
  final VoidCallback onBrowser;

  const TopicMenuSheet({
    super.key,
    required this.onJump,
    required this.onReload,
    required this.onPost,
    required this.onBrowser,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onPost();
          },
          child: const Text('コメントを投稿する'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onJump();
          },
          child: const Text('指定のコメントへジャンプ'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onBrowser();
          },
          child: const Text('ブラウザで開く'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onReload();
          },
          child: const Text('再読み込み'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDestructiveAction: true,
        onPressed: () => Navigator.pop(context),
        child: const Text('キャンセル'),
      ),
    );
  }
}
