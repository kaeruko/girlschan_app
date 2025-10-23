import 'package:flutter/cupertino.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../widgets/common/app_toast.dart';
import 'new_list.dart';
import 'topic_list.dart';
import 'favorites_screen.dart';
import 'clips_screen.dart';

class HomeScreenMacOS extends StatefulWidget {
  const HomeScreenMacOS({super.key});

  @override
  State<HomeScreenMacOS> createState() => _HomeScreenMacOSState();
}

class _HomeScreenMacOSState extends State<HomeScreenMacOS> {
  int _currentIndex = 0;
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

  // 各タブの State にアクセスするための GlobalKey
  final _newListKey = GlobalKey<NewListScreenState>();
  final _topicListKey = GlobalKey<TopicListScreenState>();

  late final List<Widget> _tabs;

  final _labels = const [
    '新着',
    '人気',
    '履歴',
    'クリップ',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = [
      NewListScreen(key: _newListKey),
      TopicListScreen(key: _topicListKey),
      const FavoritesScreen(),
      const ClipsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // macOS native風の背景色
    final backgroundColor = CupertinoColors.systemBackground;
    final topBarColor = CupertinoColors.systemGrey6.withOpacity(0.8);

    return CupertinoPageScaffold(
      navigationBar: null,
      backgroundColor: backgroundColor,
      child: Stack(
        children: [
          Row(
            children: [
              // 左サイドバー（タブメニュー）
              Container(
                width: 60,
                color: CupertinoColors.systemGrey6,
                child: Column(
                  children: List.generate(
                    _tabs.length,
                    (index) => Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() => _currentIndex = index);
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: _currentIndex == index
                                ? CupertinoColors.systemPink.withAlpha(50)
                                : CupertinoColors.transparent,
                            border: _currentIndex == index
                                ? const Border(
                                    right: BorderSide(
                                      color: CupertinoColors.systemPink,
                                      width: 3,
                                    ),
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              _labels[index],
                              style: TextStyle(
                                fontSize: 12,
                                color: _currentIndex == index
                                    ? CupertinoColors.systemPink
                                    : CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                            // 左側: 履歴ドロップダウン
                            _buildHistoryDropdown(topBarColor),
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
                                    // 検索処理
                                    print('検索ボタンクリック');
                                  },
                                ),
                                _buildActionButton(
                                  icon: CupertinoIcons.star,
                                  label: 'ブックマーク',
                                  onPressed: () {
                                    // ブックマーク処理
                                    print('ブックマークボタンクリック');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // コンテンツエリア
                    Expanded(
                      child: _tabs[_currentIndex],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ドロップダウンオーバーレイ
          if (_showHistoryDropdown)
            Positioned(
              left: 60 + 16,
              top: 44,
              child: _buildHistoryMenu(),
            ),
        ],
      ),
    );
  }

  /// 履歴ドロップダウンボタンを構築
  Widget _buildHistoryDropdown(Color topBarColor) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minSize: 0,
      onPressed: () {
        setState(() => _showHistoryDropdown = !_showHistoryDropdown);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.clock, size: 14, color: CupertinoColors.label),
          const SizedBox(width: 4),
          const Text(
            '履歴',
            style: TextStyle(fontSize: 12, color: CupertinoColors.label),
          ),
          const SizedBox(width: 4),
          Icon(
            _showHistoryDropdown
                ? CupertinoIcons.chevron_up
                : CupertinoIcons.chevron_down,
            size: 12,
            color: CupertinoColors.label,
          ),
        ],
      ),
    );
  }

  /// 履歴ドロップダウンメニューを構築
  Widget _buildHistoryMenu() {
    return Container(
      constraints: const BoxConstraints(minWidth: 250),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.separator.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._historyItems.map((item) => GestureDetector(
            onTap: () {
              setState(() {
                _selectedHistory = item;
                _showHistoryDropdown = false;
              });
              print('選択: $item');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedHistory == item
                        ? CupertinoColors.systemPink
                        : CupertinoColors.label,
                    fontWeight: _selectedHistory == item
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          )),
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
      // 現在のタブに応じて異なるリフレッシュ処理を実行
      switch (_currentIndex) {
        case 0:
          // 新着タブ: API通信を実行
          final newListState = _newListKey.currentState;
          if (newListState != null) {
            await newListState.fetchFromServer();
          }
          break;
        case 1:
          // 人気タブ: API通信を実行
          final topicListState = _topicListKey.currentState;
          if (topicListState != null) {
            await topicListState.fetchFromServer();
          }
          break;
        case 2:
          // 履歴タブ: キャッシュなし、特に処理なし
          if (mounted) {
            await AppToast.show(context, 'これ以上の履歴はありません');
          }
          break;
        case 3:
          // クリップタブ: キャッシュなし、特に処理なし
          if (mounted) {
            await AppToast.show(context, 'クリップはまだ登録されていません');
          }
          break;
      }
    } catch (e) {
      print('更新エラー: $e');
      if (mounted) {
        await AppToast.show(context, 'エラーが発生しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
}

