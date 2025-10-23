import 'package:flutter/cupertino.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '_harness.dart';

/// テスト用ダミーUIウィジェット
class TopicListScreenGoldenStub extends StatelessWidget {
  const TopicListScreenGoldenStub({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('人気'),
      ),
      child: SafeArea(
        child: ListView(
          children: List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                color: const Color(0xFFF0F0F0),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '人気トピック $i',
                      style: const TextStyle(color: CupertinoColors.black, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'コメント数: ${200 + i * 20}',
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
  testGoldens('TopicList Popular - default', (tester) async {
    await pumpGolden(tester, const TopicListScreenGoldenStub());
    await screenMatchesGolden(tester, 'topic_list_popular_default');
  });
}
