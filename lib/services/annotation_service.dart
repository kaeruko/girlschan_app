import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';

import '../config/app_config.dart';
import '../database/database.dart';
import '../models/annotation.dart';
import 'api_service.dart' as api;

typedef AnnotationTopicSearcher =
    Future<Map<String, dynamic>> Function(String query);
typedef AnnotationCommentPageFetcher =
    Future<Map<String, dynamic>> Function(
      int topicId, {
      required int offset,
      required int limit,
    });

class AnnotationService {
  AnnotationService({
    AppDatabase? database,
    AnnotationTopicSearcher? topicSearcher,
    AnnotationCommentPageFetcher? commentPageFetcher,
    DateTime Function()? now,
  }) : database = database ?? api.db,
       _topicSearcher =
           topicSearcher ?? ((query) => api.searchTopics(query: query)),
       _commentPageFetcher =
           commentPageFetcher ??
           ((topicId, {required offset, required limit}) =>
               api.fetchCommentsWithPagination(
                 topicId,
                 offset: offset,
                 limit: limit,
               )),
       _usesDefaultTopicSearcher = topicSearcher == null,
       _usesDefaultCommentFetcher = commentPageFetcher == null,
       _now = now ?? DateTime.now;

  final AppDatabase database;
  final AnnotationTopicSearcher _topicSearcher;
  final AnnotationCommentPageFetcher _commentPageFetcher;
  final bool _usesDefaultTopicSearcher;
  final bool _usesDefaultCommentFetcher;
  final DateTime Function() _now;

  Future<List<AnnotationProject>> listProjects() {
    return (database.select(
      database.annotationProjects,
    )..orderBy([(row) => OrderingTerm.desc(row.createdAt)])).get();
  }

  Future<AnnotationProject> createProject(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const AnnotationException('プロジェクト名を入力してください。');
    }

    final id = await database
        .into(database.annotationProjects)
        .insert(
          AnnotationProjectsCompanion.insert(
            name: normalizedName,
            createdAt: _now(),
          ),
        );
    return (database.select(
      database.annotationProjects,
    )..where((row) => row.id.equals(id))).getSingle();
  }

  Future<AnnotationProject> getProject(int projectId) {
    return (database.select(
      database.annotationProjects,
    )..where((row) => row.id.equals(projectId))).getSingle();
  }

  Future<List<AnnotationTopicCandidate>> searchTopicCandidates(
    String query,
  ) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw const AnnotationException('検索キーワードを入力してください。');
    }
    if (_usesDefaultTopicSearcher) {
      _requireApiBase();
    }

    final response = await _topicSearcher(normalizedQuery);
    final rawTopics = response['topics'];
    if (rawTopics is! List<dynamic>) {
      throw const FormatException('検索レスポンスの topics が配列ではありません。');
    }

    return [
      for (var index = 0; index < rawTopics.length; index++)
        _parseTopicCandidate(rawTopics[index], index),
    ];
  }

  int parseTopicIdOrUrl(String input) {
    final value = input.trim();
    final idMatch = RegExp(r'^[0-9]+$').firstMatch(value);
    final urlMatch = RegExp(
      r'^https://girlschannel\.net/topics/([0-9]+)/$',
    ).firstMatch(value);
    final rawId = idMatch?.group(0) ?? urlMatch?.group(1);
    if (rawId == null) {
      throw const AnnotationException(
        'トピックID（例: 123456）または '
        'https://girlschannel.net/topics/123456/ の形式で入力してください。',
      );
    }

    final topicId = int.parse(rawId);
    if (topicId <= 0) {
      throw const AnnotationException('トピックIDは1以上で入力してください。');
    }
    return topicId;
  }

  Future<void> addTopicFromInput(int projectId, String input) {
    final topicId = parseTopicIdOrUrl(input);
    return addTopics(projectId, [
      AnnotationTopicCandidate(topicId: topicId, title: '', totalComments: 0),
    ]);
  }

  Future<void> addTopics(
    int projectId,
    List<AnnotationTopicCandidate> candidates,
  ) async {
    if (candidates.isEmpty) {
      throw const AnnotationException('追加するトピックを選択してください。');
    }
    if (_usesDefaultCommentFetcher) {
      _requireApiBase();
    }

    await getProject(projectId);

    final candidateIds = <int>{};
    for (final candidate in candidates) {
      if (candidate.topicId <= 0) {
        throw AnnotationException('不正なトピックIDです: ${candidate.topicId}');
      }
      if (!candidateIds.add(candidate.topicId)) {
        throw AnnotationException('同じトピックが複数選択されています: ${candidate.topicId}');
      }
    }

    final existing =
        await (database.select(database.annotationTopics)..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.topicId.isIn(candidateIds),
            ))
            .get();
    if (existing.isNotEmpty) {
      final duplicateIds = existing.map((topic) => topic.topicId).join(', ');
      throw AnnotationException('このプロジェクトには既に追加済みのトピックがあります: $duplicateIds');
    }

    final fetchedTopics = <_FetchedAnnotationTopic>[];
    for (final candidate in candidates) {
      fetchedTopics.add(await _fetchCompleteTopic(candidate.topicId));
    }

    final importedAt = _now();
    await database.transaction(() async {
      for (final fetched in fetchedTopics) {
        await database
            .into(database.annotationTopics)
            .insert(
              AnnotationTopicsCompanion.insert(
                projectId: projectId,
                topicId: fetched.topicId,
                title: fetched.title,
                totalComments: fetched.total,
                addedAt: importedAt,
              ),
            );

        await database.batch((batch) {
          for (final comment in fetched.comments) {
            batch.insert(
              database.annotationItems,
              AnnotationItemsCompanion.insert(
                projectId: projectId,
                topicId: fetched.topicId,
                commentNo: comment.commentNo,
                topicTitleSnapshot: comment.topicTitle,
                bodySnapshot: comment.body,
                nameSnapshot: Value(comment.name),
                postedAtSnapshot: Value(comment.postedAt),
                plusSnapshot: comment.plus,
                minusSnapshot: comment.minus,
                anchorsSnapshot: Value(comment.anchors),
                importedAt: importedAt,
              ),
            );
          }
        });
      }
    });
  }

  Future<void> deactivateTopic(int projectId, int topicId) async {
    final changed =
        await (database.update(database.annotationTopics)..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.topicId.equals(topicId) &
                  row.isActive.equals(true),
            ))
            .write(const AnnotationTopicsCompanion(isActive: Value(false)));
    if (changed != 1) {
      throw AnnotationException('有効な対象トピックが見つかりません: $topicId');
    }
  }

  Future<List<AnnotationTopicProgress>> getTopicProgress(
    int projectId, {
    bool activeOnly = true,
  }) async {
    final topicQuery = database.select(database.annotationTopics)
      ..where((row) => row.projectId.equals(projectId))
      ..orderBy([(row) => OrderingTerm.asc(row.topicId)]);
    if (activeOnly) {
      topicQuery.where((row) => row.isActive.equals(true));
    }
    final topics = await topicQuery.get();
    final items = await (database.select(
      database.annotationItems,
    )..where((row) => row.projectId.equals(projectId))).get();

    return [
      for (final topic in topics)
        AnnotationTopicProgress(
          topicId: topic.topicId,
          title: topic.title,
          total: topic.totalComments,
          annotated: items
              .where(
                (item) => item.topicId == topic.topicId && item.label != null,
              )
              .length,
          isActive: topic.isActive,
        ),
    ];
  }

  Future<List<AnnotationItem>> getActiveItems(int projectId) async {
    final activeTopics =
        await (database.select(database.annotationTopics)..where(
              (row) =>
                  row.projectId.equals(projectId) & row.isActive.equals(true),
            ))
            .get();
    final activeIds = activeTopics.map((topic) => topic.topicId).toSet();
    if (activeIds.isEmpty) {
      return const [];
    }

    final items =
        await (database.select(database.annotationItems)..where(
              (row) =>
                  row.projectId.equals(projectId) & row.topicId.isIn(activeIds),
            ))
            .get();
    items.sort(_compareItems);
    _validateStoredLabels(items);
    return items;
  }

  int findResumeIndex(List<AnnotationItem> items) {
    _validateStoredLabels(items);
    return items.indexWhere((item) => item.label == null);
  }

  Future<void> saveLabel({
    required int projectId,
    required int topicId,
    required int commentNo,
    required AnnotationLabel label,
  }) {
    return saveLabelValue(
      projectId: projectId,
      topicId: topicId,
      commentNo: commentNo,
      label: label.value,
    );
  }

  Future<void> saveLabelValue({
    required int projectId,
    required int topicId,
    required int commentNo,
    required String label,
  }) async {
    AnnotationLabel.parse(label);
    final changed =
        await (database.update(database.annotationItems)..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.topicId.equals(topicId) &
                  row.commentNo.equals(commentNo),
            ))
            .write(
              AnnotationItemsCompanion(
                label: Value(label),
                annotatedAt: Value(_now()),
              ),
            );
    if (changed != 1) {
      throw AnnotationException(
        'アノテーション対象が見つかりません: '
        'project=$projectId topic=$topicId comment=$commentNo',
      );
    }
  }

  Future<String> buildJsonl(int projectId) async {
    final project = await getProject(projectId);
    final items = await (database.select(
      database.annotationItems,
    )..where((row) => row.projectId.equals(projectId))).get();
    items.sort(_compareItems);
    _validateStoredLabels(items);
    final lines = <String>[];

    for (final item in items) {
      final rawLabel = item.label;
      if (rawLabel == null) {
        continue;
      }
      final label = AnnotationLabel.parse(rawLabel);
      if (!label.isExportable) {
        continue;
      }
      final annotatedAt = item.annotatedAt;
      if (annotatedAt == null) {
        throw AnnotationException(
          'ラベル付きコメントの annotatedAt がありません: '
          'topic=${item.topicId} comment=${item.commentNo}',
        );
      }

      lines.add(
        jsonEncode({
          'schema_version': 1,
          'project_id': project.id,
          'project_name': project.name,
          'topic_id': item.topicId,
          'comment_no': item.commentNo,
          'topic_title': item.topicTitleSnapshot,
          'text': item.bodySnapshot,
          'label': label.value,
          'source_url':
              'https://girlschannel.net/topics/${item.topicId}/'
              '#comment${item.commentNo}',
          'annotated_at': annotatedAt.toUtc().toIso8601String(),
        }),
      );
    }

    if (lines.isEmpty) {
      throw const AnnotationException(
        '出力できるアノテーションがありません。'
        '未回答と保留はJSONLへ出力されません。',
      );
    }
    return '${lines.join('\n')}\n';
  }

  Future<bool> exportJsonl(int projectId) async {
    final contents = await buildJsonl(projectId);
    final pickerWritesContents = Platform.isAndroid || Platform.isIOS;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'アノテーションJSONLを保存',
      fileName: 'annotations_project_$projectId.jsonl',
      type: FileType.custom,
      allowedExtensions: const ['jsonl'],
      bytes: pickerWritesContents
          ? Uint8List.fromList(utf8.encode(contents))
          : null,
    );
    if (path == null) {
      return false;
    }
    if (path.trim().isEmpty) {
      throw const AnnotationException('保存先のパスが空です。');
    }

    if (!pickerWritesContents) {
      await File(path).writeAsString(contents, flush: true);
    }
    return true;
  }

  AnnotationTopicCandidate _parseTopicCandidate(Object? raw, int index) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException('topics[$index] がオブジェクトではありません。');
    }
    final id = raw['id'];
    final title = raw['title'];
    final comments = raw['comments'];
    if (id is! int || id <= 0) {
      throw FormatException('topics[$index].id が正の整数ではありません。');
    }
    if (title is! String || title.trim().isEmpty) {
      throw FormatException('topics[$index].title が空または文字列ではありません。');
    }
    if (comments is! int || comments < 0) {
      throw FormatException('topics[$index].comments が0以上の整数ではありません。');
    }
    return AnnotationTopicCandidate(
      topicId: id,
      title: title,
      totalComments: comments,
    );
  }

  Future<_FetchedAnnotationTopic> _fetchCompleteTopic(int topicId) async {
    const limit = 500;
    var offset = 0;
    int? expectedTotal;
    String? topicTitle;
    final comments = <AnnotationCommentSnapshot>[];
    final commentNumbers = <int>{};

    while (expectedTotal == null || offset < expectedTotal) {
      final page = await _commentPageFetcher(
        topicId,
        offset: offset,
        limit: limit,
      );
      final rawComments = page['comments'];
      final rawTotal = page['total'];
      final rawTitle = page['title'];
      if (rawComments is! List<dynamic>) {
        throw FormatException(
          'topic=$topicId offset=$offset: comments が配列ではありません。',
        );
      }
      if (rawTotal is! int || rawTotal < 0) {
        throw FormatException(
          'topic=$topicId offset=$offset: total が0以上の整数ではありません。',
        );
      }
      if (rawTitle is! String || rawTitle.trim().isEmpty) {
        throw FormatException(
          'topic=$topicId offset=$offset: title が空または文字列ではありません。',
        );
      }
      if (rawComments.length > limit) {
        throw FormatException(
          'topic=$topicId offset=$offset: 1ページが上限$limit件を超えています。',
        );
      }

      if (expectedTotal == null) {
        expectedTotal = rawTotal;
        topicTitle = rawTitle;
      } else {
        if (rawTotal != expectedTotal) {
          throw FormatException(
            'topic=$topicId offset=$offset: total がページ間で変化しました '
            '($expectedTotal -> $rawTotal)。',
          );
        }
        if (rawTitle != topicTitle) {
          throw FormatException(
            'topic=$topicId offset=$offset: title がページ間で変化しました。',
          );
        }
      }

      if (rawComments.isEmpty && offset < expectedTotal) {
        throw AnnotationException(
          'topic=$topicId: total=$expectedTotal に達する前に '
          'offset=$offset で空ページが返されました。',
        );
      }

      for (var index = 0; index < rawComments.length; index++) {
        final snapshot = _parseComment(
          rawComments[index],
          topicId: topicId,
          topicTitle: topicTitle!,
          offset: offset,
          pageIndex: index,
        );
        if (!commentNumbers.add(snapshot.commentNo)) {
          throw FormatException(
            'topic=$topicId: コメント番号 ${snapshot.commentNo} が重複しています。',
          );
        }
        comments.add(snapshot);
      }

      offset += rawComments.length;
      if (offset > expectedTotal) {
        throw FormatException(
          'topic=$topicId: 取得件数$offsetがtotal=$expectedTotalを超えました。',
        );
      }
      if (expectedTotal == 0) {
        break;
      }
    }

    final total = expectedTotal;
    if (comments.length != total) {
      throw AnnotationException(
        'topic=$topicId: コメント取得が不完全です '
        '(${comments.length}/$total件)。',
      );
    }
    for (var index = 0; index < comments.length; index++) {
      final expectedNumber = index + 1;
      if (comments[index].commentNo != expectedNumber) {
        throw FormatException(
          'topic=$topicId: コメント番号が欠落または順序不正です。'
          '期待値=$expectedNumber 実際=${comments[index].commentNo}',
        );
      }
    }

    return _FetchedAnnotationTopic(
      topicId: topicId,
      title: topicTitle!,
      total: total,
      comments: comments,
    );
  }

  AnnotationCommentSnapshot _parseComment(
    Object? raw, {
    required int topicId,
    required String topicTitle,
    required int offset,
    required int pageIndex,
  }) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException(
        'topic=$topicId offset=$offset comments[$pageIndex] '
        'がオブジェクトではありません。',
      );
    }
    const requiredFields = [
      'no',
      'body',
      'name',
      'posted_at',
      'plus',
      'minus',
      'anchors',
    ];
    for (final field in requiredFields) {
      if (!raw.containsKey(field)) {
        throw FormatException(
          'topic=$topicId offset=$offset comments[$pageIndex].$field '
          'がありません。',
        );
      }
    }

    final no = raw['no'];
    final body = raw['body'];
    final name = raw['name'];
    final postedAt = raw['posted_at'];
    final plus = raw['plus'];
    final minus = raw['minus'];
    final anchors = raw['anchors'];
    if (no is! int || no <= 0) {
      throw FormatException(
        'topic=$topicId offset=$offset comments[$pageIndex].no '
        'が正の整数ではありません。',
      );
    }
    if (body is! String) {
      throw FormatException('topic=$topicId comment=$no: body が文字列ではありません。');
    }
    if (name != null && name is! String) {
      throw FormatException(
        'topic=$topicId comment=$no: name が文字列またはNULLではありません。',
      );
    }
    if (postedAt != null && postedAt is! String) {
      throw FormatException(
        'topic=$topicId comment=$no: posted_at '
        'が文字列またはNULLではありません。',
      );
    }
    if (plus is! int) {
      throw FormatException('topic=$topicId comment=$no: plus が整数ではありません。');
    }
    if (minus is! int) {
      throw FormatException('topic=$topicId comment=$no: minus が整数ではありません。');
    }
    if (anchors is! List<dynamic> ||
        anchors.any((value) => value is! int || value <= 0)) {
      throw FormatException(
        'topic=$topicId comment=$no: anchors が正の整数配列ではありません。',
      );
    }

    return AnnotationCommentSnapshot(
      topicId: topicId,
      commentNo: no,
      topicTitle: topicTitle,
      body: body,
      name: name as String?,
      postedAt: postedAt as String?,
      plus: plus,
      minus: minus,
      anchors: List<int>.unmodifiable(anchors.cast<int>()),
    );
  }

  void _validateStoredLabels(Iterable<AnnotationItem> items) {
    for (final item in items) {
      final label = item.label;
      if (label != null) {
        AnnotationLabel.parse(label);
      }
    }
  }

  void _requireApiBase() {
    final base = AppConfig.apiBase.trim();
    if (base.isEmpty) {
      throw const AnnotationException('API URLが空のため、リクエストを開始できません。');
    }
  }

  static int _compareItems(AnnotationItem left, AnnotationItem right) {
    final topicComparison = left.topicId.compareTo(right.topicId);
    if (topicComparison != 0) {
      return topicComparison;
    }
    return left.commentNo.compareTo(right.commentNo);
  }
}

class _FetchedAnnotationTopic {
  const _FetchedAnnotationTopic({
    required this.topicId,
    required this.title,
    required this.total,
    required this.comments,
  });

  final int topicId;
  final String title;
  final int total;
  final List<AnnotationCommentSnapshot> comments;
}
