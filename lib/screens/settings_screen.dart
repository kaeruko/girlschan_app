import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../widgets/common/app_toast.dart';
import '../services/data_backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService();
  final _backupService = DataBackupService();

  // プリセットカラー
  final List<Color> _colors = const [
    Colors.white,
    Color(0xFFF5F5DC), // Beige
    Color(0xFFE0F7FA), // Light Cyan
    Color(0xFFFFF3E0), // Light Orange
    Color(0xFFF3E5F5), // Light Purple
    Color(0xFFFAFAFA), // Off White
    Color(0xFF121212), // Dark
  ];

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 現在の設定値
    final currentFontSize = _settings.fontSize;
    final currentBgColor = _settings.backgroundColor;
    final isDark = currentBgColor.computeLuminance() < 0.5;
    final bgColor = _settings.getBackgroundColor(context);
    final textColor = _settings.getTextColor(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('設定'),
        heroTag: 'settings_nav',
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 20),
            
            CupertinoListSection.insetGrouped(
              header: const Text('データ管理'),
              children: [
                CupertinoListTile(
                  title: Text('クリップをエクスポート', style: TextStyle(color: textColor)),
                  leading: const Icon(CupertinoIcons.share_up, color: CupertinoColors.systemBlue),
                  onTap: () => _showExportMenu(),
                ),
                CupertinoListTile(
                  title: Text('クリップをインポート', style: TextStyle(color: textColor)),
                  leading: const Icon(CupertinoIcons.arrow_down_doc, color: CupertinoColors.systemGreen),
                  onTap: () => _showImportMenu(),
                ),
              ],
            ),
            // --- 文字サイズ設定 ---
            CupertinoListSection.insetGrouped(
              header: const Text('文字サイズ'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('あ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: CupertinoSlider(
                              value: currentFontSize,
                              min: 10.0,
                              max: 24.0,
                              divisions: 14, // 1刻み
                              onChanged: (val) {
                                _settings.setFontSize(val);
                              },
                            ),
                          ),
                          const Text('あ', style: TextStyle(fontSize: 24)),
                        ],
                      ),
                      Text(
                        '現在のサイズ: ${currentFontSize.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: currentFontSize,
                          color: CupertinoColors.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- 背景色設定 ---
            CupertinoListSection.insetGrouped(
              header: const Text('背景色'),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _colors.map((color) {
                      final isSelected = color.value == currentBgColor.value;
                      return GestureDetector(
                        onTap: () => _settings.setBackgroundColor(color),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected 
                                  ? CupertinoColors.activeBlue 
                                  : CupertinoColors.systemGrey4,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: CupertinoColors.activeBlue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                            ],
                          ),
                          child: isSelected
                              ? Icon(
                                  CupertinoIcons.checkmark,
                                  color: color.computeLuminance() < 0.5 
                                      ? Colors.white 
                                      : Colors.black,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            // --- プレビュー ---
            CupertinoListSection.insetGrouped(
              header: const Text('プレビュー'),
              children: [
                Container(
                  color: currentBgColor,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100. 匿名 2024/01/01 12:00',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '文字サイズと背景色はこんな感じで表示されます。\n読みやすい設定に調整してください。',
                        style: TextStyle(
                          fontSize: currentFontSize,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExportMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('クリップのバックアップ'),
        message: const Text('保存方法を選択してください'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(modalContext);
              await _backupService.shareExportFile();
            },
            child: const Text('ファイルに保存 / 共有'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(modalContext);
              await _backupService.copyToClipboard();
              if (mounted) AppToast.show(context, 'クリップボードにコピーしました');
            },
            child: const Text('クリップボードにコピー'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(modalContext),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  void _showImportMenu() {
    showCupertinoModalPopup(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('クリップの復元'),
        message: const Text('既存のクリップに追加されます（重複はスキップ）'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(modalContext);
              try {
                final count = await _backupService.pickAndImportFile();
                if (mounted) {
                  AppToast.show(context, '$count件のクリップを復元しました');
                  // 必要なら clipsScreenStateKey.currentState?.reloadFromOutside(); で更新
                }
              } catch (e) {
                if (mounted) AppToast.show(context, 'エラー: ファイルを読み込めませんでした');
              }
            },
            child: const Text('ファイルから読み込む'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(modalContext);
              _showJsonInputDialog();
            },
            child: const Text('テキストを貼り付けて読み込む'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(modalContext),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  void _showJsonInputDialog() {
    final controller = TextEditingController();
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('JSONテキストを入力'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'ここにJSONをペースト',
            maxLines: 5,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isEmpty) return;
              
              try {
                final count = await _backupService.importFromJson(text);
                if (mounted) AppToast.show(context, '$count件のクリップを復元しました');
              } catch (e) {
                if (mounted) AppToast.show(context, '形式が正しくありません');
              }
            },
            child: const Text('読み込む'),
          ),
        ],
      ),
    );
  }

}
