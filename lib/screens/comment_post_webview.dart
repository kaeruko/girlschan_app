import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/webview_env.dart';
import '../utils/log.dart';

typedef PostCompleted = void Function(); // 戻った側で再読込する用

/// WebView ベースのコメント投稿画面（二重送信ガード・戻る統一）
class CommentPostWebView extends StatefulWidget {
  final int topicId;
  final String title;
  final Uri postPageUrl; // コメント投稿ページのURL（フォーム表示）
  final Map<String, String>
      primeCookies; // 事前投入するCookie（セッション等）
  final PostCompleted?
      onCompleted; // 完了時コールバック（一覧をrefreshなど）

  /// 投稿成功を検知するURLの接頭（例: https://example.com/post_done）
  final String successUrlPrefix;

  /// 初期テキスト（テキストエリアに事前入力）
  final String? initialText;

  /// 成功検知用テキスト（ページ内にこの文言があれば成功とみなす）
  final String? successText;

  const CommentPostWebView({
    super.key,
    required this.topicId,
    required this.title,
    required this.postPageUrl,
    this.primeCookies = const {},
    this.onCompleted,
    this.successUrlPrefix = '/post_done', // ホストを含む/含まないは後で吸収
    this.initialText,
    this.successText,
  });

  @override
  State<CommentPostWebView> createState() => _CommentPostWebViewState();
}

class _CommentPostWebViewState extends State<CommentPostWebView> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _completed = false; // 二重完了ガード
  bool _blockingClose = false; // 完了直後の連打防止
  bool _alive = true; // dispose後は false

  // 安全版 setState（_alive と mounted をチェック）
  void _safeSetState(VoidCallback fn) {
    if (!_alive || !mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController();
    _init();
  }

  Future<void> _init() async {
    if (!_alive) return;
    await WebViewEnv.primeController(_ctrl);

    // 成功検知：JS経由（フォーム submit 時に window.PostBridge.postMessage を呼ぶ想定）
    await _ctrl.addJavaScriptChannel(
      'PostBridge',
      onMessageReceived: (msg) {
        if (!_alive || !mounted) return; // ガード
        final text = msg.message.trim().toLowerCase();
        if (text == 'post_ok') {
          logd('✅ [PostBridge] post_ok 受信', name: 'CommentPostWebView');
          _markComplete('js');
        }
      },
    );

    // ナビゲーション経由の成功検知
    await _ctrl.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          if (!_alive || !mounted) return; // ガード
          logd('🌐 [onPageStarted] $url', name: 'CommentPostWebView');
          final u = Uri.tryParse(url);
          if (u != null && _isSuccessUrl(u)) {
            logd('✅ [Navigation] Success URL detected: $url',
                name: 'CommentPostWebView');
            _markComplete('nav');
          }
        },
        onPageFinished: (_) async {
          if (!_alive || !mounted) return; // ガード
          logd('✅ [onPageFinished]', name: 'CommentPostWebView');
          _safeSetState(() => _loading = false);

          if (widget.successText != null) {
            try {
              final result = await _ctrl.runJavaScriptReturningResult(
                  "document.body.innerText.includes('${widget.successText}')");
              logd('🔍 [onPageFinished] successText check result: $result', name: 'CommentPostWebView');
              if (result == true) {
                _markComplete('text_detection');
              }
            } catch (e) {
              logd('⚠️ [onPageFinished] successText check failed: $e', name: 'CommentPostWebView');
            }
          }
        },
        onNavigationRequest: (req) {
          // 完了後は全遷移をブロック（連打や戻るで二重送信しない）
          if (_completed) {
            logd('⛔ [NavigationRequest] BLOCKED (already completed): ${req.url}',
                name: 'CommentPostWebView');
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ),
    );

    // Cookie だけ先に突っ込んでおく（girlschannel のクッキー）
    await WebViewEnv.primeCookies(
      baseUri: widget.postPageUrl,
      cookies: widget.primeCookies,
    );

    // ここを分岐：
    // initialText があれば → 確認画面へ直接 POST
    // なければ → これまで通りトピックページを開く
    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      final html = buildConfirmPostHtml(
        topicId: widget.topicId,
        text: widget.initialText!,
      );
      await _ctrl.loadHtmlString(
        html,
        baseUrl: 'https://girlschannel.net/', // Referer/Origin 用
      );
    } else {
      await _ctrl.loadRequest(widget.postPageUrl);
    }
  }

  bool _isSuccessUrl(Uri u) {
    // successUrlPrefix がホスト付き/相対、両対応にしておく
    final p = widget.successUrlPrefix;
    final match = p.startsWith('http') ? u.toString().startsWith(p) : u.path.startsWith(p);
    logd('🔍 [_isSuccessUrl] url=$u prefix=$p match=$match', name: 'CommentPostWebView');
    return match;
  }

  Future<void> _markComplete(String source) async {
    if (_completed) {
      logd('⏭️ [_markComplete] Already completed, ignoring source=$source',
          name: 'CommentPostWebView');
      return; // 二重ガード
    }
    _completed = true;
    logd('🎉 [_markComplete] Marking complete (source=$source)',
        name: 'CommentPostWebView');

    // 画面上の送信ボタンなどを無効化（ページに依存しない最低限の抑止）
    unawaited(_ctrl.runJavaScriptReturningResult('''
      (function(){
        try{
          if (window.__posted) return 1;
          window.__posted = true;
          var btns = document.querySelectorAll('button[type=submit],input[type=submit]');
          btns.forEach(function(b){ b.disabled = true; b.innerText = '送信済み'; });
          return 0;
        }catch(e){return -1;}
      })();
    '''));

    _safeSetState(() => _blockingClose = true);

    // 呼び出し元に通知（一覧の再読込など）
    widget.onCompleted?.call();

    logd('⏳ [_markComplete] Waiting 300ms before closing',
        name: 'CommentPostWebView');

    // 少し待ってから安全に閉じる（UI連打の吸収）
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_alive || !mounted) return;

    // ★ Fix: 閉じるためにブロックを解除
    _safeSetState(() => _blockingClose = false);
    // ビルド反映待ち
    await Future.delayed(const Duration(milliseconds: 50));

    logd('👈 [_markComplete] Closing screen', name: 'CommentPostWebView');
    Navigator.of(context).pop(true);
  }

  Future<bool> _handleBack() async {
    // 完了済みならWebView内の戻るもしない
    if (_completed) return false;

    // WebView 内で戻れるなら戻る、無理なら画面を閉じる
    if (await _ctrl.canGoBack()) {
      logd('⬅️ [_handleBack] Going back in WebView',
          name: 'CommentPostWebView');
      await _ctrl.goBack();
      return false; // 画面は閉じない
    }
    logd('⬅️ [_handleBack] Cannot go back, closing screen',
        name: 'CommentPostWebView');
    return true; // 画面を閉じる
  }

  @override
  Widget build(BuildContext context) {
    // Flutter 3.13+ は PopScope、3.7 は WillPopScope
    return PopScope(
      canPop: !_blockingClose,
      onPopInvoked: (didPop) async {
        logd('🔙 [onPopInvoked] didPop=$didPop blockingClose=$_blockingClose', name: 'CommentPostWebView');
        if (didPop) return;
        final allow = await _handleBack();
        if (allow && mounted) {
          logd('👈 [build.onPopInvoked] Popping screen',
              name: 'CommentPostWebView');
          Navigator.of(context).pop();
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('コメント投稿 - ${widget.title}'),
          previousPageTitle: '戻る',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const CupertinoActivityIndicator()
              else
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    logd('🔄 [reload] Reloading WebView',
                        name: 'CommentPostWebView');
                    _ctrl.reload();
                  },
                  child: const Icon(CupertinoIcons.refresh),
                ),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _ctrl),
              if (_loading)
                const Center(child: CupertinoActivityIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _alive = false; // 以後すべてのコールバックを無視
    logd('🗑️ [dispose] Disposing CommentPostWebView',
        name: 'CommentPostWebView');
    super.dispose();
  }
}

/// 文字列をJavaScriptリテラルにエスケープ
String _escapeForJs(String s) => jsonEncode(s);

String buildConfirmPostHtml({
    required int topicId,
    required String text,
  }) {
    // textarea 中身としてエスケープ
    final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(text);

    return '''
<!doctype html>
<html lang="ja">
  <head>
    <meta charset="utf-8">
  </head>
  <body>
    <form id="f"
      action="https://girlschannel.net/make_comment/$topicId/"
      method="POST"
      enctype="multipart/form-data">

      <!-- 本文 -->
      <textarea name="text" style="display:none;">$escaped</textarea>

      <!-- ファイルは使わないが、元フォームと同じ name だけ用意しておく -->
      <input type="file" name="add_pic" style="display:none;" />

      <!-- 名前（空のまま） -->
      <input type="hidden" name="name" value="">

      <!-- 匿名で投稿（チェック済み相当） -->
      <input type="hidden" name="anonymous" value="匿名で投稿">

      <!-- 元フォームと同じ hidden -->
      <input type="hidden" name="is_next" value="0">
      <input type="hidden" name="is_post" value="1">

    </form>
    <script>
      // ページ読み込み直後に自動で送信 → サーバ側の確認画面が返ってくる
      document.getElementById('f').submit();
    </script>
  </body>
</html>
''';
  }

