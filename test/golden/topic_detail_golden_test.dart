import 'package:flutter/cupertino.dart' show CupertinoApp;
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import '_harness.dart';
import 'package:girlschan_app/screens/topic_detail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TopicDetail - cached first page (basic)', (tester) async {
    const topicId = 5888874;

    final comments = <Map<String, dynamic>>[
      {
        'no': 1,
        'name': '匿名',
        'time': '2025-10-20 12:00',
        'body': '最初のコメント。テキストだけの基本形。',
        'plus': 12,
        'minus': 3,
        'anchors': [2],
        'reverse_anchors': [3, 5],
      },
      {
        'no': 2,
        'name': '匿名',
        'time': '2025-10-20 12:05',
        'body': '>>1 への返信。URLプレビューなしで安定表示。',
        'plus': 4,
        'minus': 0,
        'anchors': [1],
        'reverse_anchors': [5],
        'urls': const [],
      },
      {
        'no': 3,
        'name': '匿名',
        'time': '2025-10-20 12:10',
        'body': '長文テスト。' * 8,
        'plus': 0,
        'minus': 0,
        'anchors': const [],
        'reverse_anchors': const [],
      },
    ];

    await pumpGolden(
      tester,
      TopicDetailScreen(
        topicId: topicId,
        title: 'ゴールデン用テストトピック',
        commentCount: comments.length,
        enableRefresh: false,          // ★ リフレッシュ無効
        testingBypassInit: true,       // ★ 初期ロード全部無効
        testingInitialComments: comments,
      ),
      size: const Size(390, 844),
    );

    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('goldens/topic_detail_cached_basic.png'),
    );
  });

  testWidgets('TopicDetail - cached with image & anchors', (tester) async {
    await mockNetworkImagesFor(() async {
      const topicId = 5888875;

      final comments = <Map<String, dynamic>>[
        {
          'no': 10,
          'name': '匿名',
          'time': '2025-10-21 09:00',
          'body': '画像つきコメントの表示確認。',
          'plus': 5,
          'minus': 1,
          'anchors': [11, 12],
          'reverse_anchors': [13, 14, 15, 16, 17, 18],
          'image_url': 'https://example.com/mock.jpg', // モックされる
        },
        {
          'no': 11,
          'name': '匿名',
          'time': '2025-10-21 09:05',
          'body': '>>10 返信。＋/−のバーが出るケース。',
          'plus': 2,
          'minus': 2,
          'anchors': [10],
        },
      ];

      await pumpGolden(
        tester,
        TopicDetailScreen(
          topicId: topicId,
          title: '画像とアンカーの表示確認',
          commentCount: comments.length,
          enableRefresh: false,          // ★
          testingBypassInit: true,       // ★
          testingInitialComments: comments,
        ),
        size: const Size(390, 844),
      );

      await expectLater(
        find.byType(CupertinoApp),
        matchesGoldenFile('goldens/topic_detail_cached_with_image.png'),
      );
    });
  });
}
