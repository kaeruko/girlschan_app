import 'package:flutter/cupertino.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../app/app_tabs.dart';
import '../router/app_router.dart';

class MacShell extends StatefulWidget {
  final List<TabSpec> tabs;
  const MacShell({super.key, required this.tabs});

  @override
  State<MacShell> createState() => _MacShellState();
}

class _MacShellState extends State<MacShell> {
  int _index = 0;
  bool _showHistoryDropdown = false;
  bool _isRefreshing = false;

  List<String> _historyItems = [
    'テスト履歴1',
    'テスト履歴2',
    'テスト履歴3',
    'テスト履歴4',
    'テスト履歴5',
  ];
  String? _selectedHistory;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground;
    final topBarColor = CupertinoColors.systemGrey6.withOpacity(0.8);
    final current = widget.tabs[_index];

    return CupertinoPageScaffold(
      navigationBar: null,
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          Row(
            children: [
              // 左サイドバー（タブメニュー）
              Container(
                width: 220,
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
              // メインコンテンツ
              Expanded(
                child: Column(
                  children: [
                    // フラットな上部バー（SafariやXcode風）
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanStart: (_) => appWindow.startDragging(),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: topBarColor,
                          border: Border(
                            bottom: BorderSide(
                              color: CupertinoColors.separator.withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // 左側: タイトル
                            Text(
                              current.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            // 右側: アクションボタン
                            Row(
                              children: [
                                _buildActionButton(
                                  icon: CupertinoIcons.arrow_clockwise,
                                  label: '更新',
                                  isLoading: _isRefreshing,
                                  onPressed: _isRefreshing ? null : _handleRefresh,
                                ),
                                _buildActionButton(
                                  icon: CupertinoIcons.search,
                                  label: '検索',
                                  onPressed: () {
                                    print('検索ボタンクリック');
                                  },
                                ),
                                _buildActionButton(
                                  icon: CupertinoIcons.star,
                                  label: 'ブックマーク',
                                  onPressed: () {
                                    print('ブックマークボタンクリック');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // コンテンツエリア：タブの builder から画面を生成
                    Expanded(
                      child: KeyedSubtree(
                        key: PageStorageKey('mac_${current.id}'),
                        child: current.builder(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  /// アクションボタンを構築
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minSize: 0,
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
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // 更新処理はタブ側で個別に定義されているはず
      // 今はプレースホルダー
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('更新エラー: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
}
