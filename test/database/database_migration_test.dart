import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:girlschan_app/database/database.dart';

void main() {
  test('schema 2から3へ既存データを保持したまま移行する', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'girlschan_annotation_migration_',
    );
    final databaseFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}migration.sqlite',
    );

    try {
      final oldExecutor = NativeDatabase(databaseFile);
      await oldExecutor.ensureOpen(const _SchemaV2User());
      await _createV2Schema(oldExecutor);
      await oldExecutor.close();

      final database = AppDatabase(NativeDatabase(databaseFile));
      try {
        final topics = await database.select(database.topics).get();
        final comments = await database.select(database.comments).get();
        final labels = await database.select(database.clipLabels).get();

        expect(database.schemaVersion, 3);
        expect(topics.single.title, '既存トピック');
        expect(comments.single.body, '既存コメント');
        expect(comments.single.isClipped, isTrue);
        expect(labels.single.name, '既存ラベル');
        expect(
          await database.select(database.annotationProjects).get(),
          isEmpty,
        );
        expect(await database.select(database.annotationTopics).get(), isEmpty);
        expect(await database.select(database.annotationItems).get(), isEmpty);
      } finally {
        await database.close();
      }
    } finally {
      if (tempDirectory.existsSync()) {
        for (var attempt = 0; attempt < 5; attempt++) {
          try {
            await tempDirectory.delete(recursive: true);
            break;
          } on FileSystemException {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        }
      }
    }
  });
}

class _SchemaV2User implements QueryExecutorUser {
  const _SchemaV2User();

  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

Future<void> _createV2Schema(QueryExecutor executor) async {
  await executor.runCustom('''
      CREATE TABLE topics (
        id INTEGER NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        comment_count INTEGER NOT NULL DEFAULT 0,
        posted_at TEXT NULL,
        thumbnail TEXT NULL,
        last_viewed_at INTEGER NULL,
        fetched_at INTEGER NULL
      )
    ''');
  await executor.runCustom('''
      CREATE TABLE comments (
        topic_id INTEGER NOT NULL REFERENCES topics (id),
        number INTEGER NOT NULL,
        body TEXT NOT NULL,
        name TEXT NULL,
        posted_at TEXT NULL,
        plus INTEGER NOT NULL DEFAULT 0,
        minus INTEGER NOT NULL DEFAULT 0,
        image_url TEXT NULL,
        original_image_url TEXT NULL,
        anchors TEXT NOT NULL DEFAULT '[]',
        reverse_anchors TEXT NOT NULL DEFAULT '[]',
        is_clipped INTEGER NOT NULL DEFAULT 0,
        clipped_at INTEGER NULL,
        clip_memo TEXT NULL,
        label_id INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (topic_id, number)
      )
    ''');
  await executor.runCustom('''
      CREATE TABLE clip_labels (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  await executor.runCustom('''
      INSERT INTO topics (
        id, title, comment_count, posted_at, last_viewed_at, fetched_at
      ) VALUES (123, '既存トピック', 1, '2026-07-31', 1, 1)
    ''');
  await executor.runCustom('''
      INSERT INTO comments (
        topic_id, number, body, name, posted_at, plus, minus,
        anchors, reverse_anchors, is_clipped, label_id
      ) VALUES (
        123, 1, '既存コメント', '匿名', '2026-07-31',
        10, 1, '[]', '[]', 1, 1
      )
    ''');
  await executor.runCustom('''
      INSERT INTO clip_labels (id, name, created_at)
      VALUES (1, '既存ラベル', 1)
    ''');
}
