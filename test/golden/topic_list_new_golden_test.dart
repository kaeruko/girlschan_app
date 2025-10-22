import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:girlschan_app/screens/new_list.dart';
import 'package:girlschan_app/widgets/topic_tile.dart';
import '_harness.dart';

/// テスト用ダミーUIウィジェット
/// 実際の API 呼び出しなしで、レイアウトを表示
class NewListScreenGoldenStub extends StatefulWidget {
  const NewListScreenGoldenStub({super.key});

  @override
  State<NewListScreenGoldenStub> createState() => _NewListScreenGoldenStubState();
}

class _NewListScreenGoldenStubState extends State<NewListScreenGoldenStub> {
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('新着'),
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
                      'テストトピック $i',
                      style: const TextStyle(color: CupertinoColors.black, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'コメント数: ${100 + i * 10}',
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
  testGoldens('TopicList New - default', (tester) async {
    await pumpGolden(tester, const NewListScreenGoldenStub());
    await screenMatchesGolden(tester, 'topic_list_new_default');
  });
}

