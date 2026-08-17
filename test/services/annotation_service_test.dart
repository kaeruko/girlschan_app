import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:girlschan_app/database/database.dart';
import 'package:girlschan_app/models/annotation.dart';
import 'package:girlschan_app/services/annotation_service.dart';

void main() {
  late AppDatabase database;
  late AnnotationService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    service = AnnotationService(
      database: database,
      commentPageFetcher: _completePageFetcher,
      now: () => DateTime.utc(2026, 7, 31, 3),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('同じ対象トピックを二重登録できない', () async {
    final project = await service.createProject('重複テスト');
    const candidate = AnnotationTopicCandidate(
      topicId: 10,
      title: 'Topic 10',
      totalComments: 2,
    );

    await service.addTopics(project.id, const [candidate]);

    await expectLater(
      service.addTopics(project.id, const [candidate]),
      throwsA(isA<AnnotationException>()),
    );
    final topics = await database.select(database.annotationTopics).get();
    expect(topics, hasLength(1));
  });

  test('アノテーションを保存して上書きできる', () async {
    final project = await service.createProject('保存テスト');
    await service.addTopics(project.id, const [
      AnnotationTopicCandidate(
        topicId: 10,
        title: 'Topic 10',
        totalComments: 2,
      ),
    ]);

    await service.saveLabel(
      projectId: project.id,
      topicId: 10,
      commentNo: 1,
      label: AnnotationLabel.experience,
    );
    await service.saveLabel(
      projectId: project.id,
      topicId: 10,
      commentNo: 1,
      label: AnnotationLabel.notExperience,
    );

    final item =
        await (database.select(database.annotationItems)..where(
              (row) =>
                  row.projectId.equals(project.id) &
                  row.topicId.equals(10) &
                  row.commentNo.equals(1),
            ))
            .getSingle();
    expect(item.label, 'not_experience');
    expect(item.annotatedAt?.toUtc(), DateTime.utc(2026, 7, 31, 3));
  });

  test('アプリ再起動相当のサービス再生成後も最初の未回答から再開する', () async {
    final project = await service.createProject('再開テスト');
    await service.addTopics(project.id, const [
      AnnotationTopicCandidate(
        topicId: 10,
        title: 'Topic 10',
        totalComments: 2,
      ),
    ]);
    await service.saveLabel(
      projectId: project.id,
      topicId: 10,
      commentNo: 1,
      label: AnnotationLabel.experience,
    );

    final restartedService = AnnotationService(
      database: database,
      commentPageFetcher: _completePageFetcher,
    );
    final items = await restartedService.getActiveItems(project.id);

    expect(restartedService.findResumeIndex(items), 1);
    expect(items[1].commentNo, 2);
  });

  test('未知のラベル値は例外になる', () async {
    final project = await service.createProject('ラベルテスト');
    await service.addTopics(project.id, const [
      AnnotationTopicCandidate(
        topicId: 10,
        title: 'Topic 10',
        totalComments: 2,
      ),
    ]);

    await expectLater(
      service.saveLabelValue(
        projectId: project.id,
        topicId: 10,
        commentNo: 1,
        label: 'unknown',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('JSONLは未回答と保留を除外しtopic_id、comment_no順になる', () async {
    final project = await service.createProject('JSONLテスト');
    await service.addTopics(project.id, const [
      AnnotationTopicCandidate(
        topicId: 20,
        title: 'Topic 20',
        totalComments: 2,
      ),
      AnnotationTopicCandidate(
        topicId: 10,
        title: 'Topic 10',
        totalComments: 2,
      ),
    ]);
    await service.saveLabel(
      projectId: project.id,
      topicId: 20,
      commentNo: 1,
      label: AnnotationLabel.skipped,
    );
    await service.saveLabel(
      projectId: project.id,
      topicId: 20,
      commentNo: 2,
      label: AnnotationLabel.experience,
    );
    await service.saveLabel(
      projectId: project.id,
      topicId: 10,
      commentNo: 1,
      label: AnnotationLabel.notExperience,
    );

    final jsonl = await service.buildJsonl(project.id);
    final rows = LineSplitter.split(
      jsonl,
    ).map((line) => jsonDecode(line) as Map<String, dynamic>).toList();

    expect(rows, hasLength(2));
    expect(rows.map((row) => [row['topic_id'], row['comment_no']]).toList(), [
      [10, 1],
      [20, 2],
    ]);
    expect(rows.map((row) => row['label']).toList(), [
      'not_experience',
      'experience',
    ]);
  });

  test('コメント取得がtotal到達前に途切れた場合は登録全体に失敗する', () async {
    Future<Map<String, dynamic>> incompleteFetcher(
      int topicId, {
      required int offset,
      required int limit,
    }) async {
      return {
        'title': 'Topic $topicId',
        'total': 3,
        'comments': offset == 0
            ? [_comment(1), _comment(2)]
            : <Map<String, dynamic>>[],
      };
    }

    final incompleteService = AnnotationService(
      database: database,
      commentPageFetcher: incompleteFetcher,
    );
    final project = await incompleteService.createProject('中断テスト');

    await expectLater(
      incompleteService.addTopics(project.id, const [
        AnnotationTopicCandidate(
          topicId: 10,
          title: 'Topic 10',
          totalComments: 3,
        ),
      ]),
      throwsA(isA<AnnotationException>()),
    );
    expect(await database.select(database.annotationTopics).get(), isEmpty);
    expect(await database.select(database.annotationItems).get(), isEmpty);
  });

  test('対象から外してもトピックとアノテーション項目を物理削除しない', () async {
    final project = await service.createProject('論理削除テスト');
    await service.addTopics(project.id, const [
      AnnotationTopicCandidate(
        topicId: 10,
        title: 'Topic 10',
        totalComments: 2,
      ),
    ]);

    await service.deactivateTopic(project.id, 10);

    final topic = await database.select(database.annotationTopics).getSingle();
    expect(topic.isActive, isFalse);
    expect(await database.select(database.annotationItems).get(), hasLength(2));
  });

  test('出力対象が0件ならJSONLを生成しない', () async {
    final project = await service.createProject('空出力テスト');

    await expectLater(
      service.buildJsonl(project.id),
      throwsA(isA<AnnotationException>()),
    );
  });

  test('IDまたは完全一致URL以外は受け付けない', () {
    expect(service.parseTopicIdOrUrl('123456'), 123456);
    expect(
      service.parseTopicIdOrUrl('https://girlschannel.net/topics/123456/'),
      123456,
    );
    expect(
      () => service.parseTopicIdOrUrl('https://girlschannel.net/topics/123456'),
      throwsA(isA<AnnotationException>()),
    );
    expect(
      () => service.parseTopicIdOrUrl('topic=123456'),
      throwsA(isA<AnnotationException>()),
    );
  });
}

Future<Map<String, dynamic>> _completePageFetcher(
  int topicId, {
  required int offset,
  required int limit,
}) async {
  final allComments = [_comment(1), _comment(2)];
  final end = (offset + limit).clamp(0, allComments.length);
  return {
    'title': 'Topic $topicId',
    'total': allComments.length,
    'comments': offset >= allComments.length
        ? <Map<String, dynamic>>[]
        : allComments.sublist(offset, end),
  };
}

Map<String, dynamic> _comment(int number) {
  return {
    'no': number,
    'body': 'Comment $number',
    'name': '匿名',
    'posted_at': '2026-07-31 12:00:00',
    'plus': number,
    'minus': 0,
    'anchors': number == 2 ? [1] : <int>[],
  };
}
