// widgets/topic_menu_sheet.dart (または該当ファイル)

import 'package:flutter/cupertino.dart';

class TopicMenuSheet extends StatelessWidget {
  final VoidCallback onJump;
  final VoidCallback onReload;
  final VoidCallback onPost;
  final VoidCallback onBrowser;
  final VoidCallback onFilter; // ★ 追加

  const TopicMenuSheet({
    super.key,
    required this.onJump,
    required this.onReload,
    required this.onPost,
    required this.onBrowser,
    required this.onFilter, // ★ 追加
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
          child: const Text('書き込む'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onJump();
          },
          child: const Text('コメントへジャンプ'),
        ),
        // ★ ここに追加
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context); // メニューを閉じて
            onFilter(); // フィルター画面を開く
          },
          child: const Text('コメントを絞り込む'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onReload();
          },
          child: const Text('再読み込み'),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            onBrowser();
          },
          child: const Text('ブラウザで開く'),
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