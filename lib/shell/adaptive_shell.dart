import 'package:flutter/widgets.dart';
import '../app/app_tabs.dart';
import '../utils/platform_helper.dart';
import 'ios_shell.dart';
import 'macos_shell.dart';
import 'windows_shell.dart';

/// プラットフォーム別に適切なシェルを選択
/// iOS: IOSShell（ボトムタブ）
/// macOS/Windows: MacShell/WindowsShell（サイドバー）
class AdaptiveShell extends StatelessWidget {
  final List<TabSpec> tabs;
  const AdaptiveShell({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isMacOS) return MacShell(tabs: tabs);
    if (PlatformHelper.isWindows) return WindowsShell(tabs: tabs);
    return IOSShell(tabs: tabs);
  }
}
