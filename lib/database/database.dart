import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart'; // build_runnerで自動生成されるファイル

// ==========================================
// 🛠️ Type Converters (リストなどを保存するため)
// ==========================================
class ListConverter extends TypeConverter<List<String>, String> {
  const ListConverter();
  @override
  List<String> fromSql(String fromDb) => List<String>.from(json.decode(fromDb));
  @override
  String toSql(List<String> value) => json.encode(value);
}

class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();
  @override
  List<int> fromSql(String fromDb) => List<int>.from(json.decode(fromDb));
  @override
  String toSql(List<int> value) => json.encode(value);
}

// ==========================================
// 📄 Tables
// ==========================================

/// トピックテーブル
/// APIキャッシュと閲覧履歴を兼ねる
@DataClassName('TopicEntry')
class Topics extends Table {
  // APIのIDをそのまま主キーにする
  IntColumn get id => integer()();
  TextColumn get title => text()();
  IntColumn get commentCount => integer().withDefault(const Constant(0))();
  TextColumn get postedAt => text().nullable()(); // APIの日付文字列
  TextColumn get thumbnail => text().nullable()();
  
  // ▼ キャッシュ・履歴管理用フィールド
  /// 最終閲覧日時（履歴機能用）。NULLなら履歴にない。
  DateTimeColumn get lastViewedAt => dateTime().nullable()();
  /// データ取得日時（キャッシュ有効期限判定用）
  DateTimeColumn get fetchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// コメントテーブル
/// トピックID + コメント番号 で一意になる
@DataClassName('CommentEntry')
class Comments extends Table {
  IntColumn get topicId => integer().references(Topics, #id)();
  IntColumn get number => integer()(); // コメント番号 (no)
  TextColumn get body => text()();
  TextColumn get name => text().nullable()();
  TextColumn get postedAt => text().nullable()();
  IntColumn get plus => integer().withDefault(const Constant(0))();
  IntColumn get minus => integer().withDefault(const Constant(0))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get originalImageUrl => text().nullable()();
  
  // JSON変換して保存するカラム
  TextColumn get anchors => text().map(const IntListConverter()).withDefault(const Constant('[]'))();
  TextColumn get reverseAnchors => text().map(const IntListConverter()).withDefault(const Constant('[]'))();

  // ▼ クリップ機能用フィールド
  /// クリップされているか
  BoolColumn get isClipped => boolean().withDefault(const Constant(false))();
  /// クリップした日時
  DateTimeColumn get clippedAt => dateTime().nullable()();
  /// メモ（ユーザー入力）
  TextColumn get clipMemo => text().nullable()();
  /// ラベルID
  IntColumn get labelId => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {topicId, number};
}

/// クリップラベルテーブル
class ClipLabels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

// ==========================================
// 🏠 Database Class
// ==========================================
@DriftDatabase(tables: [Topics, Comments, ClipLabels])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          // comments テーブルに original_image_url カラムを追加
          await m.addColumn(comments, comments.originalImageUrl);
        }
      },
      beforeOpen: (details) async {
        // 必要に応じて処理を追加
      },
    );
  }

  // ▼ ここにデータ操作メソッド(DAO)を書いていく

  // --- トピック関連 ---

  /// APIから取得したトピック一覧を保存（Upsert）
  /// 既存の履歴データ（lastViewedAt）は消さずに、タイトルやコメ数だけ更新する
  Future<void> upsertTopics(List<TopicsCompanion> entries) async {
    await batch((batch) {
      for (final row in entries) {
        batch.insert(
          topics,
          row,
          onConflict: DoUpdate((_) => TopicsCompanion.custom(
            title: row.title.present ? Constant(row.title.value) : null,
            commentCount: row.commentCount.present ? Constant(row.commentCount.value) : null,
            postedAt: row.postedAt.present ? Constant(row.postedAt.value) : null,
            thumbnail: row.thumbnail.present ? Constant(row.thumbnail.value) : null,
            fetchedAt: Constant(DateTime.now()), // 取得日時を更新
            // lastViewedAt は更新しない（履歴を保持）
          )),
        );
      }
    });
  }

  /// 閲覧履歴の更新
  Future<void> markTopicAsViewed(
    int topicId, {
    String? title,
    int? commentCount,
    String? postedAt,
    String? thumbnail,
  }) async {
    await (update(topics)..where((t) => t.id.equals(topicId))).write(
      TopicsCompanion(
        lastViewedAt: Value(DateTime.now()),
        title: title != null ? Value(title) : Value.absent(),
        commentCount: commentCount != null ? Value(commentCount) : Value.absent(),
        postedAt: postedAt != null ? Value(postedAt) : Value.absent(),
        thumbnail: thumbnail != null ? Value(thumbnail) : Value.absent(),
      ),
    );
  }

  /// 履歴一覧の取得
  Future<List<TopicEntry>> getHistory({int limit = 50}) {
    return (select(topics)
      ..where((t) => t.lastViewedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.lastViewedAt)])
      ..limit(limit)
    ).get();
  }

  // --- コメント関連 ---

  /// APIから取得したコメントを保存
  /// ※ クリップ情報（isClipped, memo等）は上書きしないように注意する
  Future<void> upsertComments(List<CommentsCompanion> entries) async {
    await batch((batch) {
      for (final row in entries) {
        batch.insert(
          comments,
          row,
          onConflict: DoUpdate((old) => CommentsCompanion.custom(
            body: Constant(row.body.value),
            plus: Constant(row.plus.value),
            minus: Constant(row.minus.value),
            imageUrl: row.imageUrl.present ? Constant(row.imageUrl.value) : null,
            originalImageUrl: row.originalImageUrl.present ? Constant(row.originalImageUrl.value) : null,
            anchors: Constant(const IntListConverter().toSql(row.anchors.value)),
            reverseAnchors: Constant(const IntListConverter().toSql(row.reverseAnchors.value)),
            // isClipped, clipMemo 等は更新しないことで維持する
          )),
        );
      }
    });
  }
  
  /// トピックID指定でコメント取得
  Future<List<CommentEntry>> getCommentsForTopic(int topicId) {
    return (select(comments)
      ..where((c) => c.topicId.equals(topicId))
      ..orderBy([(c) => OrderingTerm.asc(c.number)])
    ).get();
  }
  
  /// クリップ操作（保存）
  Future<void> toggleClip(int tId, int num, bool clipped) async {
     await (update(comments)..where((c) => c.topicId.equals(tId) & c.number.equals(num))).write(
      CommentsCompanion(
        isClipped: Value(clipped),
        clippedAt: Value(clipped ? DateTime.now() : null),
      ),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
    return NativeDatabase(file);
  });
}
