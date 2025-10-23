import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../app/app_tabs.dart';
import '../router/app_router.dart';
import '../utils/log.dart';
import '../screens/search_screen.dart';

class MacShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const MacShell({super.key, required this.tabs});

  @override
  State<MacShell> createState() => _MacShellState();
}

class _MacShellState extends State<MacShell> {
  int _index = 0;
  bool _isRefreshing = false;
  double _captionHeight = 28; // デフォルト（fallback）

  @override
  void initState() {
    super.initState();
    _loadCaptionHeight();
  }

  Future<void> _loadCaptionHeight() async {
    try {
      final h = await windowManager.getTitleBarHeight(); // int?
      if (!mounted) return;
      if (h != null && h > 0) {
        setState(() => _captionHeight = h.toDouble());
      }
    } catch (_) {
      // 取得できない環境では fallback の 28.0 を使う
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.tabs[_index];

    return CupertinoPageScaffold(
      navigationBar: null,
      child: Column(
        children: [
          // OSの信号ボタン用のスペーサ（ここは何も描かない）
          SizedBox(height: _captionHeight),
          // 自前ツールバー（信号の"下"から始める）
          _buildTopToolbar(),
          // 本体
          Expanded(
            child: Row(
              children: [
                // 左サイドバー（タブメニュー）
                SizedBox(
                  width: 220,
                  child: Container(
                    color: CupertinoColors.systemGrey6,
                    child: CupertinoScrollbar(
                      child: ListView.builder(
                        itemCount: widget.tabs.length,
                        itemBuilder: (context, i) {
                          final t = widget.tabs[i];
                          final selected = i == _index;
                          return _buildSidebarItem(
                            icon: t.icon,
                            label: t.label,
                            selected: selected,
                            onTap: () => setState(() => _index = i),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  color: CupertinoColors.separator,
                ),
                // メインコンテンツ
                Expanded(
                  child: KeyedSubtree(
                    key: PageStorageKey('mac_${current.id}'),
                    child: IndexedStack(
                      index: _index,
                      children: [
                        for (int i = 0; i < widget.tabs.length; i++)
                          CupertinoTabView(
                            key: PageStorageKey('tab_view_$i'),
                            onGenerateRoute: AppRouter.onGenerateRoute,
                            builder: (ctx) => widget.tabs[i].builder(ctx),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// サイドバー項目を構築
  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: selected
              ? CupertinoColors.systemPink.withAlpha(50)
              : CupertinoColors.transparent,
          border: selected
              ? const Border(
                  right: BorderSide(
                    color: CupertinoColors.systemPink,
                    width: 3,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? CupertinoColors.systemPink
                  : CupertinoColors.systemGrey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? CupertinoColors.systemPink
                      : CupertinoColors.systemGrey,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) const Icon(CupertinoIcons.check_mark, size: 14),
          ],
        ),
      ),
    );
  }

  /// 自前ツールバーを構築
  Widget _buildTopToolbar() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          const SizedBox(width: 12),
          _buildActionButton(
            icon: CupertinoIcons.arrow_clockwise,
            label: '更新',
            isLoading: _isRefreshing,
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
          _buildActionButton(
            icon: CupertinoIcons.search,
            label: '検索',
            onPressed: _showSearchDialog,
          ),
          const Spacer(),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  /// アクションボタンを構築
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size.square(0),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading && label == '更新')
            const SizedBox(
              width: 14,
              height: 14,
              child: CupertinoActivityIndicator(radius: 7),
            )
          else
            Icon(icon, size: 14, color: CupertinoColors.label),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: CupertinoColors.label,
            ),
          ),
        ],
      ),
    );
  }

  /// 更新ボタンのハンドラー
  Future<void> _handleRefresh() async {
    if (_isRefreshing) {
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      
      // TabSpec の stateKey を使用して各タブの fetchFromServer() を呼び出す
      final stateKey = widget.tabs[_index].stateKey;
      if (stateKey != null) {
        final state = stateKey.currentState;
        if (state != null && state.mounted) {
          await (state as dynamic).fetchFromServer();
        } else {
        }
      } else {
      }
    } catch (e) {
      logd('[🔴 ERROR] 更新エラー: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        logd('[🔵 DEBUG] Set _isRefreshing = false');
      }
    }
  }

  /// 検索ダイアログを表示
  Future<void> _showSearchDialog() async {
    final controller = TextEditingController();
    
    final query = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogCtx) => Dialog(
        insetAnimationDuration: const Duration(milliseconds: 200),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '検索',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 20),
              CupertinoTextField(
                controller: controller,
                placeholder: 'キーワードを入力',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.separator),
                  borderRadius: BorderRadius.circular(8),
                ),
                onSubmitted: (value) => Navigator.pop(dialogCtx, value.trim()),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton(
                    color: CupertinoColors.systemBlue,
                    onPressed: () => Navigator.pop(dialogCtx, controller.text.trim()),
                    child: const Text('検索'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    controller.dispose();

    if (query == null || query.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    // 検索結果画面に遷移（初期クエリを渡す）
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => SearchScreen(initialQuery: query),
      ),
    );
  }
}
