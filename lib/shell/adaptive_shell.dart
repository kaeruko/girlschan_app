import 'dart:io';
import 'package:flutter/widgets.dart';
import '../app/app_tabs.dart';
import 'ios_shell.dart';
import 'macos_shell.dart';

/// プラットフォーム別に適切なシェルを選択
/// iOS: IOSShell（ボトムタブ）
/// macOS: MacShell（サイドバー）
class AdaptiveShell extends StatelessWidget {
  final List<TabSpec> tabs;
  const AdaptiveShell({super.key, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Platform.isMacOS ? MacShell(tabs: tabs) : IOSShell(tabs: tabs);
  }
}
