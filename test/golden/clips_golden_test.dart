import 'package:flutter/cupertino.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '_harness.dart';

/// テスト用ダミーUIウィジェット
class ClipsScreenGoldenStub extends StatelessWidget {
  const ClipsScreenGoldenStub({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('クリップ'),
      ),
      child: SafeArea(
        child: ListView(
          children: List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                color: const Color(0xFFF0F0F0),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'クリップ済みコメント $i',
                      style: const TextStyle(color: CupertinoColors.black, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'トピック $i',
                      style: const TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testGoldens('Clips - default', (tester) async {
    await pumpGolden(tester, const ClipsScreenGoldenStub());
    await screenMatchesGolden(tester, 'clips_default');
  });
}
