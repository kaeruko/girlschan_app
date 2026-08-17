import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:girlschan_app/app/app_tabs.dart';
import 'package:girlschan_app/shell/adaptive_shell.dart';
import 'package:girlschan_app/shell/ios_shell.dart';
import 'package:girlschan_app/utils/platform_helper.dart';

void main() {
  tearDown(() {
    PlatformHelper.setTestPlatform(null);
  });

  testWidgets('Androidではアノテーションをモバイルタブとして表示する', (tester) async {
    PlatformHelper.setTestPlatform(PlatformKind.android);
    final tabs = [
      TabSpec(
        id: 'tab_test',
        label: 'テスト',
        icon: CupertinoIcons.home,
        title: 'テスト',
        builder: (_) => const SizedBox(),
      ),
      TabSpec(
        id: 'tab_annotation',
        label: 'アノテーション',
        icon: CupertinoIcons.tag,
        title: 'コメントアノテーション',
        builder: (_) => const SizedBox(),
      ),
    ];

    await tester.pumpWidget(CupertinoApp(home: AdaptiveShell(tabs: tabs)));
    await tester.pumpAndSettle();

    expect(find.byType(IOSShell), findsOneWidget);
    expect(find.text('注釈'), findsOneWidget);
  });
}
