import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:girlschan_app/database/database.dart';
import 'package:girlschan_app/models/annotation.dart';
import 'package:girlschan_app/screens/annotation_screen.dart';
import 'package:girlschan_app/services/annotation_service.dart';

void main() {
  testWidgets('トピック追加画面から手動で戻ってもDBの追加内容を再読込する', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final service = AnnotationService(
      database: database,
      commentPageFetcher: _pageFetcher,
    );
    final project = await service.createProject('再読込テスト');

    await tester.pumpWidget(
      CupertinoApp(home: AnnotationScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(project.name));
    await tester.pumpAndSettle();

    await tester.tap(find.text('対象トピックを追加'));
    await tester.pumpAndSettle();

    await service.addTopics(project.id, const [
      AnnotationTopicCandidate(
        topicId: 10,
        title: 'Topic 10',
        totalComments: 1,
      ),
    ]);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Topic 10'), findsWidgets);
    expect(find.textContaining('ID 10'), findsOneWidget);
  });
}

Future<Map<String, dynamic>> _pageFetcher(
  int topicId, {
  required int offset,
  required int limit,
}) async {
  return {
    'title': 'Topic $topicId',
    'total': 1,
    'comments': offset == 0
        ? [
            {
              'no': 1,
              'body': 'Comment 1',
              'name': '匿名',
              'posted_at': '2026-07-31 12:00:00',
              'plus': 0,
              'minus': 0,
              'anchors': <int>[],
            },
          ]
        : <Map<String, dynamic>>[],
  };
}
