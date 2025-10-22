import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:girlschan_app/screens/favorites_screen.dart';
import '_harness.dart';

/// テスト用ダミーUIウィジェット
class FavoritesScreenGoldenStub extends StatelessWidget {
  const FavoritesScreenGoldenStub({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('お気に入り'),
      ),
      child: SafeArea(
        child: ListView(
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                color: const Color(0xFFF0F0F0),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'お気に入りトピック $i',
                      style: const TextStyle(color: CupertinoColors.black, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'コメント数: ${50 + i * 5}',
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
  testGoldens('Favorites - default', (tester) async {
    await pumpGolden(tester, const FavoritesScreenGoldenStub());
    await screenMatchesGolden(tester, 'favorites_default');
  });
}
