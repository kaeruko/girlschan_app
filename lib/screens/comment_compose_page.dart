import 'package:flutter/cupertino.dart';
import 'comment_post_webview.dart';
import '../services/cache_service.dart';

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
  bool _canPop = false; // PopScopeで戻るを制御

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _loadDraft();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// 下書きを読み込む
  Future<void> _loadDraft() async {
    // initialTextが指定されている場合は優先
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _ctrl.text = widget.initialText!;
      return;
    }

    // 下書きがあれば読み込む
    final draft = await CacheService.loadDraft(widget.topicId);
    if (draft != null && draft.isNotEmpty) {
      _ctrl.text = draft;
    }
  }

  /// 下書き保存ダイアログを表示
  Future<bool> _showSaveDraftDialog() async {
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('下書きに保存しますか？'),
        content: const Text('入力中のテキストを下書きとして保存できます。'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('no'),
            child: const Text('いいえ'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop('yes'),
            child: const Text('はい'),
          ),
        ],
      ),
    );

    if (result == 'yes') {
      // 下書きを保存
      await CacheService.saveDraft(widget.topicId, _ctrl.text.trim());
      return true; // 画面を閉じる
    } else if (result == 'no') {
      // 保存せずに閉じる
      return true;
    } else {
      // キャンセル（画面を閉じない）
      return false;
    }
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
          successText: 'コメント投稿完了', // ★ 成功検知用テキスト
        ),
      ),
    );

    setState(() => _posting = false);

    // WebView 側で投稿完了したら pop(true) する想定
    if (result == true) {
      // ★ 投稿成功時に下書きを削除
      await CacheService.deleteDraft(widget.topicId);
      
      if (mounted) {
        setState(() => _canPop = true);
        Navigator.of(context).pop(text); // 一個前の画面に「投稿したよ」と返す（テキストも渡す）
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // テキストが入力されている場合のみダイアログを表示
        final text = _ctrl.text.trim();
        if (text.isEmpty) {
          // 空の場合はそのまま閉じる
          setState(() => _canPop = true);
          if (mounted) {
            final nav = Navigator.of(context);
            nav.pop();
          }
          return;
        }

        // 下書き保存ダイアログを表示
        final shouldPop = await _showSaveDraftDialog();
        if (shouldPop && mounted) {
          setState(() => _canPop = true);
          final nav = Navigator.of(context);
          nav.pop();
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('コメント入力'),
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
            child: Column(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: CupertinoTextField(
                    controller: _ctrl,
                    maxLines: null,
                    minLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    placeholder: 'コメントを書く',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}