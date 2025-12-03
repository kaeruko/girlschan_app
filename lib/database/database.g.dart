// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TopicsTable extends Topics with TableInfo<$TopicsTable, Topic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _commentCountMeta =
      const VerificationMeta('commentCount');
  @override
  late final GeneratedColumn<int> commentCount = GeneratedColumn<int>(
      'comment_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _postedAtMeta =
      const VerificationMeta('postedAt');
  @override
  late final GeneratedColumn<String> postedAt = GeneratedColumn<String>(
      'posted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _thumbnailMeta =
      const VerificationMeta('thumbnail');
  @override
  late final GeneratedColumn<String> thumbnail = GeneratedColumn<String>(
      'thumbnail', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastViewedAtMeta =
      const VerificationMeta('lastViewedAt');
  @override
  late final GeneratedColumn<DateTime> lastViewedAt = GeneratedColumn<DateTime>(
      'last_viewed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, commentCount, postedAt, thumbnail, lastViewedAt, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topics';
  @override
  VerificationContext validateIntegrity(Insertable<Topic> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('comment_count')) {
      context.handle(
          _commentCountMeta,
          commentCount.isAcceptableOrUnknown(
              data['comment_count']!, _commentCountMeta));
    }
    if (data.containsKey('posted_at')) {
      context.handle(_postedAtMeta,
          postedAt.isAcceptableOrUnknown(data['posted_at']!, _postedAtMeta));
    }
    if (data.containsKey('thumbnail')) {
      context.handle(_thumbnailMeta,
          thumbnail.isAcceptableOrUnknown(data['thumbnail']!, _thumbnailMeta));
    }
    if (data.containsKey('last_viewed_at')) {
      context.handle(
          _lastViewedAtMeta,
          lastViewedAt.isAcceptableOrUnknown(
              data['last_viewed_at']!, _lastViewedAtMeta));
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Topic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Topic(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      commentCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}comment_count'])!,
      postedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}posted_at']),
      thumbnail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail']),
      lastViewedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_viewed_at']),
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at']),
    );
  }

  @override
  $TopicsTable createAlias(String alias) {
    return $TopicsTable(attachedDatabase, alias);
  }
}

class Topic extends DataClass implements Insertable<Topic> {
  final int id;
  final String title;
  final int commentCount;
  final String? postedAt;
  final String? thumbnail;

  /// 最終閲覧日時（履歴機能用）。NULLなら履歴にない。
  final DateTime? lastViewedAt;

  /// データ取得日時（キャッシュ有効期限判定用）
  final DateTime? fetchedAt;
  const Topic(
      {required this.id,
      required this.title,
      required this.commentCount,
      this.postedAt,
      this.thumbnail,
      this.lastViewedAt,
      this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['comment_count'] = Variable<int>(commentCount);
    if (!nullToAbsent || postedAt != null) {
      map['posted_at'] = Variable<String>(postedAt);
    }
    if (!nullToAbsent || thumbnail != null) {
      map['thumbnail'] = Variable<String>(thumbnail);
    }
    if (!nullToAbsent || lastViewedAt != null) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt);
    }
    if (!nullToAbsent || fetchedAt != null) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt);
    }
    return map;
  }

  TopicsCompanion toCompanion(bool nullToAbsent) {
    return TopicsCompanion(
      id: Value(id),
      title: Value(title),
      commentCount: Value(commentCount),
      postedAt: postedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(postedAt),
      thumbnail: thumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnail),
      lastViewedAt: lastViewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastViewedAt),
      fetchedAt: fetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fetchedAt),
    );
  }

  factory Topic.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Topic(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      commentCount: serializer.fromJson<int>(json['commentCount']),
      postedAt: serializer.fromJson<String?>(json['postedAt']),
      thumbnail: serializer.fromJson<String?>(json['thumbnail']),
      lastViewedAt: serializer.fromJson<DateTime?>(json['lastViewedAt']),
      fetchedAt: serializer.fromJson<DateTime?>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'commentCount': serializer.toJson<int>(commentCount),
      'postedAt': serializer.toJson<String?>(postedAt),
      'thumbnail': serializer.toJson<String?>(thumbnail),
      'lastViewedAt': serializer.toJson<DateTime?>(lastViewedAt),
      'fetchedAt': serializer.toJson<DateTime?>(fetchedAt),
    };
  }

  Topic copyWith(
          {int? id,
          String? title,
          int? commentCount,
          Value<String?> postedAt = const Value.absent(),
          Value<String?> thumbnail = const Value.absent(),
          Value<DateTime?> lastViewedAt = const Value.absent(),
          Value<DateTime?> fetchedAt = const Value.absent()}) =>
      Topic(
        id: id ?? this.id,
        title: title ?? this.title,
        commentCount: commentCount ?? this.commentCount,
        postedAt: postedAt.present ? postedAt.value : this.postedAt,
        thumbnail: thumbnail.present ? thumbnail.value : this.thumbnail,
        lastViewedAt:
            lastViewedAt.present ? lastViewedAt.value : this.lastViewedAt,
        fetchedAt: fetchedAt.present ? fetchedAt.value : this.fetchedAt,
      );
  Topic copyWithCompanion(TopicsCompanion data) {
    return Topic(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      commentCount: data.commentCount.present
          ? data.commentCount.value
          : this.commentCount,
      postedAt: data.postedAt.present ? data.postedAt.value : this.postedAt,
      thumbnail: data.thumbnail.present ? data.thumbnail.value : this.thumbnail,
      lastViewedAt: data.lastViewedAt.present
          ? data.lastViewedAt.value
          : this.lastViewedAt,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Topic(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('commentCount: $commentCount, ')
          ..write('postedAt: $postedAt, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, title, commentCount, postedAt, thumbnail, lastViewedAt, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Topic &&
          other.id == this.id &&
          other.title == this.title &&
          other.commentCount == this.commentCount &&
          other.postedAt == this.postedAt &&
          other.thumbnail == this.thumbnail &&
          other.lastViewedAt == this.lastViewedAt &&
          other.fetchedAt == this.fetchedAt);
}

class TopicsCompanion extends UpdateCompanion<Topic> {
  final Value<int> id;
  final Value<String> title;
  final Value<int> commentCount;
  final Value<String?> postedAt;
  final Value<String?> thumbnail;
  final Value<DateTime?> lastViewedAt;
  final Value<DateTime?> fetchedAt;
  const TopicsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.commentCount = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  TopicsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.commentCount = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Topic> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? commentCount,
    Expression<String>? postedAt,
    Expression<String>? thumbnail,
    Expression<DateTime>? lastViewedAt,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (commentCount != null) 'comment_count': commentCount,
      if (postedAt != null) 'posted_at': postedAt,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (lastViewedAt != null) 'last_viewed_at': lastViewedAt,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  TopicsCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<int>? commentCount,
      Value<String?>? postedAt,
      Value<String?>? thumbnail,
      Value<DateTime?>? lastViewedAt,
      Value<DateTime?>? fetchedAt}) {
    return TopicsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      commentCount: commentCount ?? this.commentCount,
      postedAt: postedAt ?? this.postedAt,
      thumbnail: thumbnail ?? this.thumbnail,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (commentCount.present) {
      map['comment_count'] = Variable<int>(commentCount.value);
    }
    if (postedAt.present) {
      map['posted_at'] = Variable<String>(postedAt.value);
    }
    if (thumbnail.present) {
      map['thumbnail'] = Variable<String>(thumbnail.value);
    }
    if (lastViewedAt.present) {
      map['last_viewed_at'] = Variable<DateTime>(lastViewedAt.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('commentCount: $commentCount, ')
          ..write('postedAt: $postedAt, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class $CommentsTable extends Comments with TableInfo<$CommentsTable, Comment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CommentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _topicIdMeta =
      const VerificationMeta('topicId');
  @override
  late final GeneratedColumn<int> topicId = GeneratedColumn<int>(
      'topic_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES topics (id)'));
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
      'number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _postedAtMeta =
      const VerificationMeta('postedAt');
  @override
  late final GeneratedColumn<String> postedAt = GeneratedColumn<String>(
      'posted_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _plusMeta = const VerificationMeta('plus');
  @override
  late final GeneratedColumn<int> plus = GeneratedColumn<int>(
      'plus', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _minusMeta = const VerificationMeta('minus');
  @override
  late final GeneratedColumn<int> minus = GeneratedColumn<int>(
      'minus', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String> anchors =
      GeneratedColumn<String>('anchors', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('[]'))
          .withConverter<List<int>>($CommentsTable.$converteranchors);
  @override
  late final GeneratedColumnWithTypeConverter<List<int>, String>
      reverseAnchors = GeneratedColumn<String>(
              'reverse_anchors', aliasedName, false,
              type: DriftSqlType.string,
              requiredDuringInsert: false,
              defaultValue: const Constant('[]'))
          .withConverter<List<int>>($CommentsTable.$converterreverseAnchors);
  static const VerificationMeta _isClippedMeta =
      const VerificationMeta('isClipped');
  @override
  late final GeneratedColumn<bool> isClipped = GeneratedColumn<bool>(
      'is_clipped', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_clipped" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _clippedAtMeta =
      const VerificationMeta('clippedAt');
  @override
  late final GeneratedColumn<DateTime> clippedAt = GeneratedColumn<DateTime>(
      'clipped_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _clipMemoMeta =
      const VerificationMeta('clipMemo');
  @override
  late final GeneratedColumn<String> clipMemo = GeneratedColumn<String>(
      'clip_memo', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _labelIdMeta =
      const VerificationMeta('labelId');
  @override
  late final GeneratedColumn<int> labelId = GeneratedColumn<int>(
      'label_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        topicId,
        number,
        body,
        name,
        postedAt,
        plus,
        minus,
        imageUrl,
        anchors,
        reverseAnchors,
        isClipped,
        clippedAt,
        clipMemo,
        labelId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comments';
  @override
  VerificationContext validateIntegrity(Insertable<Comment> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('topic_id')) {
      context.handle(_topicIdMeta,
          topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta));
    } else if (isInserting) {
      context.missing(_topicIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('posted_at')) {
      context.handle(_postedAtMeta,
          postedAt.isAcceptableOrUnknown(data['posted_at']!, _postedAtMeta));
    }
    if (data.containsKey('plus')) {
      context.handle(
          _plusMeta, plus.isAcceptableOrUnknown(data['plus']!, _plusMeta));
    }
    if (data.containsKey('minus')) {
      context.handle(
          _minusMeta, minus.isAcceptableOrUnknown(data['minus']!, _minusMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('is_clipped')) {
      context.handle(_isClippedMeta,
          isClipped.isAcceptableOrUnknown(data['is_clipped']!, _isClippedMeta));
    }
    if (data.containsKey('clipped_at')) {
      context.handle(_clippedAtMeta,
          clippedAt.isAcceptableOrUnknown(data['clipped_at']!, _clippedAtMeta));
    }
    if (data.containsKey('clip_memo')) {
      context.handle(_clipMemoMeta,
          clipMemo.isAcceptableOrUnknown(data['clip_memo']!, _clipMemoMeta));
    }
    if (data.containsKey('label_id')) {
      context.handle(_labelIdMeta,
          labelId.isAcceptableOrUnknown(data['label_id']!, _labelIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {topicId, number};
  @override
  Comment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Comment(
      topicId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}topic_id'])!,
      number: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}number'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      postedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}posted_at']),
      plus: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}plus'])!,
      minus: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}minus'])!,
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      anchors: $CommentsTable.$converteranchors.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}anchors'])!),
      reverseAnchors: $CommentsTable.$converterreverseAnchors.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}reverse_anchors'])!),
      isClipped: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_clipped'])!,
      clippedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}clipped_at']),
      clipMemo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}clip_memo']),
      labelId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}label_id'])!,
    );
  }

  @override
  $CommentsTable createAlias(String alias) {
    return $CommentsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<int>, String> $converteranchors =
      const IntListConverter();
  static TypeConverter<List<int>, String> $converterreverseAnchors =
      const IntListConverter();
}

class Comment extends DataClass implements Insertable<Comment> {
  final int topicId;
  final int number;
  final String body;
  final String? name;
  final String? postedAt;
  final int plus;
  final int minus;
  final String? imageUrl;
  final List<int> anchors;
  final List<int> reverseAnchors;

  /// クリップされているか
  final bool isClipped;

  /// クリップした日時
  final DateTime? clippedAt;

  /// メモ（ユーザー入力）
  final String? clipMemo;

  /// ラベルID
  final int labelId;
  const Comment(
      {required this.topicId,
      required this.number,
      required this.body,
      this.name,
      this.postedAt,
      required this.plus,
      required this.minus,
      this.imageUrl,
      required this.anchors,
      required this.reverseAnchors,
      required this.isClipped,
      this.clippedAt,
      this.clipMemo,
      required this.labelId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['topic_id'] = Variable<int>(topicId);
    map['number'] = Variable<int>(number);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || postedAt != null) {
      map['posted_at'] = Variable<String>(postedAt);
    }
    map['plus'] = Variable<int>(plus);
    map['minus'] = Variable<int>(minus);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    {
      map['anchors'] =
          Variable<String>($CommentsTable.$converteranchors.toSql(anchors));
    }
    {
      map['reverse_anchors'] = Variable<String>(
          $CommentsTable.$converterreverseAnchors.toSql(reverseAnchors));
    }
    map['is_clipped'] = Variable<bool>(isClipped);
    if (!nullToAbsent || clippedAt != null) {
      map['clipped_at'] = Variable<DateTime>(clippedAt);
    }
    if (!nullToAbsent || clipMemo != null) {
      map['clip_memo'] = Variable<String>(clipMemo);
    }
    map['label_id'] = Variable<int>(labelId);
    return map;
  }

  CommentsCompanion toCompanion(bool nullToAbsent) {
    return CommentsCompanion(
      topicId: Value(topicId),
      number: Value(number),
      body: Value(body),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      postedAt: postedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(postedAt),
      plus: Value(plus),
      minus: Value(minus),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      anchors: Value(anchors),
      reverseAnchors: Value(reverseAnchors),
      isClipped: Value(isClipped),
      clippedAt: clippedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clippedAt),
      clipMemo: clipMemo == null && nullToAbsent
          ? const Value.absent()
          : Value(clipMemo),
      labelId: Value(labelId),
    );
  }

  factory Comment.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Comment(
      topicId: serializer.fromJson<int>(json['topicId']),
      number: serializer.fromJson<int>(json['number']),
      body: serializer.fromJson<String>(json['body']),
      name: serializer.fromJson<String?>(json['name']),
      postedAt: serializer.fromJson<String?>(json['postedAt']),
      plus: serializer.fromJson<int>(json['plus']),
      minus: serializer.fromJson<int>(json['minus']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      anchors: serializer.fromJson<List<int>>(json['anchors']),
      reverseAnchors: serializer.fromJson<List<int>>(json['reverseAnchors']),
      isClipped: serializer.fromJson<bool>(json['isClipped']),
      clippedAt: serializer.fromJson<DateTime?>(json['clippedAt']),
      clipMemo: serializer.fromJson<String?>(json['clipMemo']),
      labelId: serializer.fromJson<int>(json['labelId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'topicId': serializer.toJson<int>(topicId),
      'number': serializer.toJson<int>(number),
      'body': serializer.toJson<String>(body),
      'name': serializer.toJson<String?>(name),
      'postedAt': serializer.toJson<String?>(postedAt),
      'plus': serializer.toJson<int>(plus),
      'minus': serializer.toJson<int>(minus),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'anchors': serializer.toJson<List<int>>(anchors),
      'reverseAnchors': serializer.toJson<List<int>>(reverseAnchors),
      'isClipped': serializer.toJson<bool>(isClipped),
      'clippedAt': serializer.toJson<DateTime?>(clippedAt),
      'clipMemo': serializer.toJson<String?>(clipMemo),
      'labelId': serializer.toJson<int>(labelId),
    };
  }

  Comment copyWith(
          {int? topicId,
          int? number,
          String? body,
          Value<String?> name = const Value.absent(),
          Value<String?> postedAt = const Value.absent(),
          int? plus,
          int? minus,
          Value<String?> imageUrl = const Value.absent(),
          List<int>? anchors,
          List<int>? reverseAnchors,
          bool? isClipped,
          Value<DateTime?> clippedAt = const Value.absent(),
          Value<String?> clipMemo = const Value.absent(),
          int? labelId}) =>
      Comment(
        topicId: topicId ?? this.topicId,
        number: number ?? this.number,
        body: body ?? this.body,
        name: name.present ? name.value : this.name,
        postedAt: postedAt.present ? postedAt.value : this.postedAt,
        plus: plus ?? this.plus,
        minus: minus ?? this.minus,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        anchors: anchors ?? this.anchors,
        reverseAnchors: reverseAnchors ?? this.reverseAnchors,
        isClipped: isClipped ?? this.isClipped,
        clippedAt: clippedAt.present ? clippedAt.value : this.clippedAt,
        clipMemo: clipMemo.present ? clipMemo.value : this.clipMemo,
        labelId: labelId ?? this.labelId,
      );
  Comment copyWithCompanion(CommentsCompanion data) {
    return Comment(
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
      number: data.number.present ? data.number.value : this.number,
      body: data.body.present ? data.body.value : this.body,
      name: data.name.present ? data.name.value : this.name,
      postedAt: data.postedAt.present ? data.postedAt.value : this.postedAt,
      plus: data.plus.present ? data.plus.value : this.plus,
      minus: data.minus.present ? data.minus.value : this.minus,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      anchors: data.anchors.present ? data.anchors.value : this.anchors,
      reverseAnchors: data.reverseAnchors.present
          ? data.reverseAnchors.value
          : this.reverseAnchors,
      isClipped: data.isClipped.present ? data.isClipped.value : this.isClipped,
      clippedAt: data.clippedAt.present ? data.clippedAt.value : this.clippedAt,
      clipMemo: data.clipMemo.present ? data.clipMemo.value : this.clipMemo,
      labelId: data.labelId.present ? data.labelId.value : this.labelId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Comment(')
          ..write('topicId: $topicId, ')
          ..write('number: $number, ')
          ..write('body: $body, ')
          ..write('name: $name, ')
          ..write('postedAt: $postedAt, ')
          ..write('plus: $plus, ')
          ..write('minus: $minus, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('anchors: $anchors, ')
          ..write('reverseAnchors: $reverseAnchors, ')
          ..write('isClipped: $isClipped, ')
          ..write('clippedAt: $clippedAt, ')
          ..write('clipMemo: $clipMemo, ')
          ..write('labelId: $labelId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      topicId,
      number,
      body,
      name,
      postedAt,
      plus,
      minus,
      imageUrl,
      anchors,
      reverseAnchors,
      isClipped,
      clippedAt,
      clipMemo,
      labelId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Comment &&
          other.topicId == this.topicId &&
          other.number == this.number &&
          other.body == this.body &&
          other.name == this.name &&
          other.postedAt == this.postedAt &&
          other.plus == this.plus &&
          other.minus == this.minus &&
          other.imageUrl == this.imageUrl &&
          other.anchors == this.anchors &&
          other.reverseAnchors == this.reverseAnchors &&
          other.isClipped == this.isClipped &&
          other.clippedAt == this.clippedAt &&
          other.clipMemo == this.clipMemo &&
          other.labelId == this.labelId);
}

class CommentsCompanion extends UpdateCompanion<Comment> {
  final Value<int> topicId;
  final Value<int> number;
  final Value<String> body;
  final Value<String?> name;
  final Value<String?> postedAt;
  final Value<int> plus;
  final Value<int> minus;
  final Value<String?> imageUrl;
  final Value<List<int>> anchors;
  final Value<List<int>> reverseAnchors;
  final Value<bool> isClipped;
  final Value<DateTime?> clippedAt;
  final Value<String?> clipMemo;
  final Value<int> labelId;
  final Value<int> rowid;
  const CommentsCompanion({
    this.topicId = const Value.absent(),
    this.number = const Value.absent(),
    this.body = const Value.absent(),
    this.name = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.plus = const Value.absent(),
    this.minus = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.anchors = const Value.absent(),
    this.reverseAnchors = const Value.absent(),
    this.isClipped = const Value.absent(),
    this.clippedAt = const Value.absent(),
    this.clipMemo = const Value.absent(),
    this.labelId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommentsCompanion.insert({
    required int topicId,
    required int number,
    required String body,
    this.name = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.plus = const Value.absent(),
    this.minus = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.anchors = const Value.absent(),
    this.reverseAnchors = const Value.absent(),
    this.isClipped = const Value.absent(),
    this.clippedAt = const Value.absent(),
    this.clipMemo = const Value.absent(),
    this.labelId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : topicId = Value(topicId),
        number = Value(number),
        body = Value(body);
  static Insertable<Comment> custom({
    Expression<int>? topicId,
    Expression<int>? number,
    Expression<String>? body,
    Expression<String>? name,
    Expression<String>? postedAt,
    Expression<int>? plus,
    Expression<int>? minus,
    Expression<String>? imageUrl,
    Expression<String>? anchors,
    Expression<String>? reverseAnchors,
    Expression<bool>? isClipped,
    Expression<DateTime>? clippedAt,
    Expression<String>? clipMemo,
    Expression<int>? labelId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (topicId != null) 'topic_id': topicId,
      if (number != null) 'number': number,
      if (body != null) 'body': body,
      if (name != null) 'name': name,
      if (postedAt != null) 'posted_at': postedAt,
      if (plus != null) 'plus': plus,
      if (minus != null) 'minus': minus,
      if (imageUrl != null) 'image_url': imageUrl,
      if (anchors != null) 'anchors': anchors,
      if (reverseAnchors != null) 'reverse_anchors': reverseAnchors,
      if (isClipped != null) 'is_clipped': isClipped,
      if (clippedAt != null) 'clipped_at': clippedAt,
      if (clipMemo != null) 'clip_memo': clipMemo,
      if (labelId != null) 'label_id': labelId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommentsCompanion copyWith(
      {Value<int>? topicId,
      Value<int>? number,
      Value<String>? body,
      Value<String?>? name,
      Value<String?>? postedAt,
      Value<int>? plus,
      Value<int>? minus,
      Value<String?>? imageUrl,
      Value<List<int>>? anchors,
      Value<List<int>>? reverseAnchors,
      Value<bool>? isClipped,
      Value<DateTime?>? clippedAt,
      Value<String?>? clipMemo,
      Value<int>? labelId,
      Value<int>? rowid}) {
    return CommentsCompanion(
      topicId: topicId ?? this.topicId,
      number: number ?? this.number,
      body: body ?? this.body,
      name: name ?? this.name,
      postedAt: postedAt ?? this.postedAt,
      plus: plus ?? this.plus,
      minus: minus ?? this.minus,
      imageUrl: imageUrl ?? this.imageUrl,
      anchors: anchors ?? this.anchors,
      reverseAnchors: reverseAnchors ?? this.reverseAnchors,
      isClipped: isClipped ?? this.isClipped,
      clippedAt: clippedAt ?? this.clippedAt,
      clipMemo: clipMemo ?? this.clipMemo,
      labelId: labelId ?? this.labelId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (topicId.present) {
      map['topic_id'] = Variable<int>(topicId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (postedAt.present) {
      map['posted_at'] = Variable<String>(postedAt.value);
    }
    if (plus.present) {
      map['plus'] = Variable<int>(plus.value);
    }
    if (minus.present) {
      map['minus'] = Variable<int>(minus.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (anchors.present) {
      map['anchors'] = Variable<String>(
          $CommentsTable.$converteranchors.toSql(anchors.value));
    }
    if (reverseAnchors.present) {
      map['reverse_anchors'] = Variable<String>(
          $CommentsTable.$converterreverseAnchors.toSql(reverseAnchors.value));
    }
    if (isClipped.present) {
      map['is_clipped'] = Variable<bool>(isClipped.value);
    }
    if (clippedAt.present) {
      map['clipped_at'] = Variable<DateTime>(clippedAt.value);
    }
    if (clipMemo.present) {
      map['clip_memo'] = Variable<String>(clipMemo.value);
    }
    if (labelId.present) {
      map['label_id'] = Variable<int>(labelId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommentsCompanion(')
          ..write('topicId: $topicId, ')
          ..write('number: $number, ')
          ..write('body: $body, ')
          ..write('name: $name, ')
          ..write('postedAt: $postedAt, ')
          ..write('plus: $plus, ')
          ..write('minus: $minus, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('anchors: $anchors, ')
          ..write('reverseAnchors: $reverseAnchors, ')
          ..write('isClipped: $isClipped, ')
          ..write('clippedAt: $clippedAt, ')
          ..write('clipMemo: $clipMemo, ')
          ..write('labelId: $labelId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClipLabelsTable extends ClipLabels
    with TableInfo<$ClipLabelsTable, ClipLabel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClipLabelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clip_labels';
  @override
  VerificationContext validateIntegrity(Insertable<ClipLabel> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClipLabel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClipLabel(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ClipLabelsTable createAlias(String alias) {
    return $ClipLabelsTable(attachedDatabase, alias);
  }
}

class ClipLabel extends DataClass implements Insertable<ClipLabel> {
  final int id;
  final String name;
  final DateTime createdAt;
  const ClipLabel(
      {required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ClipLabelsCompanion toCompanion(bool nullToAbsent) {
    return ClipLabelsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory ClipLabel.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClipLabel(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ClipLabel copyWith({int? id, String? name, DateTime? createdAt}) => ClipLabel(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  ClipLabel copyWithCompanion(ClipLabelsCompanion data) {
    return ClipLabel(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClipLabel(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClipLabel &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class ClipLabelsCompanion extends UpdateCompanion<ClipLabel> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const ClipLabelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ClipLabelsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ClipLabel> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ClipLabelsCompanion copyWith(
      {Value<int>? id, Value<String>? name, Value<DateTime>? createdAt}) {
    return ClipLabelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClipLabelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TopicsTable topics = $TopicsTable(this);
  late final $CommentsTable comments = $CommentsTable(this);
  late final $ClipLabelsTable clipLabels = $ClipLabelsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [topics, comments, clipLabels];
}

typedef $$TopicsTableCreateCompanionBuilder = TopicsCompanion Function({
  Value<int> id,
  required String title,
  Value<int> commentCount,
  Value<String?> postedAt,
  Value<String?> thumbnail,
  Value<DateTime?> lastViewedAt,
  Value<DateTime?> fetchedAt,
});
typedef $$TopicsTableUpdateCompanionBuilder = TopicsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<int> commentCount,
  Value<String?> postedAt,
  Value<String?> thumbnail,
  Value<DateTime?> lastViewedAt,
  Value<DateTime?> fetchedAt,
});

final class $$TopicsTableReferences
    extends BaseReferences<_$AppDatabase, $TopicsTable, Topic> {
  $$TopicsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CommentsTable, List<Comment>> _commentsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.comments,
          aliasName: $_aliasNameGenerator(db.topics.id, db.comments.topicId));

  $$CommentsTableProcessedTableManager get commentsRefs {
    final manager = $$CommentsTableTableManager($_db, $_db.comments)
        .filter((f) => f.topicId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_commentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TopicsTableFilterComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get commentCount => $composableBuilder(
      column: $table.commentCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get postedAt => $composableBuilder(
      column: $table.postedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnail => $composableBuilder(
      column: $table.thumbnail, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastViewedAt => $composableBuilder(
      column: $table.lastViewedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> commentsRefs(
      Expression<bool> Function($$CommentsTableFilterComposer f) f) {
    final $$CommentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.comments,
        getReferencedColumn: (t) => t.topicId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommentsTableFilterComposer(
              $db: $db,
              $table: $db.comments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TopicsTableOrderingComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get commentCount => $composableBuilder(
      column: $table.commentCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get postedAt => $composableBuilder(
      column: $table.postedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnail => $composableBuilder(
      column: $table.thumbnail, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastViewedAt => $composableBuilder(
      column: $table.lastViewedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$TopicsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TopicsTable> {
  $$TopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get commentCount => $composableBuilder(
      column: $table.commentCount, builder: (column) => column);

  GeneratedColumn<String> get postedAt =>
      $composableBuilder(column: $table.postedAt, builder: (column) => column);

  GeneratedColumn<String> get thumbnail =>
      $composableBuilder(column: $table.thumbnail, builder: (column) => column);

  GeneratedColumn<DateTime> get lastViewedAt => $composableBuilder(
      column: $table.lastViewedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  Expression<T> commentsRefs<T extends Object>(
      Expression<T> Function($$CommentsTableAnnotationComposer a) f) {
    final $$CommentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.comments,
        getReferencedColumn: (t) => t.topicId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$CommentsTableAnnotationComposer(
              $db: $db,
              $table: $db.comments,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TopicsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TopicsTable,
    Topic,
    $$TopicsTableFilterComposer,
    $$TopicsTableOrderingComposer,
    $$TopicsTableAnnotationComposer,
    $$TopicsTableCreateCompanionBuilder,
    $$TopicsTableUpdateCompanionBuilder,
    (Topic, $$TopicsTableReferences),
    Topic,
    PrefetchHooks Function({bool commentsRefs})> {
  $$TopicsTableTableManager(_$AppDatabase db, $TopicsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> commentCount = const Value.absent(),
            Value<String?> postedAt = const Value.absent(),
            Value<String?> thumbnail = const Value.absent(),
            Value<DateTime?> lastViewedAt = const Value.absent(),
            Value<DateTime?> fetchedAt = const Value.absent(),
          }) =>
              TopicsCompanion(
            id: id,
            title: title,
            commentCount: commentCount,
            postedAt: postedAt,
            thumbnail: thumbnail,
            lastViewedAt: lastViewedAt,
            fetchedAt: fetchedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            Value<int> commentCount = const Value.absent(),
            Value<String?> postedAt = const Value.absent(),
            Value<String?> thumbnail = const Value.absent(),
            Value<DateTime?> lastViewedAt = const Value.absent(),
            Value<DateTime?> fetchedAt = const Value.absent(),
          }) =>
              TopicsCompanion.insert(
            id: id,
            title: title,
            commentCount: commentCount,
            postedAt: postedAt,
            thumbnail: thumbnail,
            lastViewedAt: lastViewedAt,
            fetchedAt: fetchedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$TopicsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({commentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (commentsRefs) db.comments],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (commentsRefs)
                    await $_getPrefetchedData<Topic, $TopicsTable, Comment>(
                        currentTable: table,
                        referencedTable:
                            $$TopicsTableReferences._commentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TopicsTableReferences(db, table, p0).commentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.topicId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TopicsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TopicsTable,
    Topic,
    $$TopicsTableFilterComposer,
    $$TopicsTableOrderingComposer,
    $$TopicsTableAnnotationComposer,
    $$TopicsTableCreateCompanionBuilder,
    $$TopicsTableUpdateCompanionBuilder,
    (Topic, $$TopicsTableReferences),
    Topic,
    PrefetchHooks Function({bool commentsRefs})>;
typedef $$CommentsTableCreateCompanionBuilder = CommentsCompanion Function({
  required int topicId,
  required int number,
  required String body,
  Value<String?> name,
  Value<String?> postedAt,
  Value<int> plus,
  Value<int> minus,
  Value<String?> imageUrl,
  Value<List<int>> anchors,
  Value<List<int>> reverseAnchors,
  Value<bool> isClipped,
  Value<DateTime?> clippedAt,
  Value<String?> clipMemo,
  Value<int> labelId,
  Value<int> rowid,
});
typedef $$CommentsTableUpdateCompanionBuilder = CommentsCompanion Function({
  Value<int> topicId,
  Value<int> number,
  Value<String> body,
  Value<String?> name,
  Value<String?> postedAt,
  Value<int> plus,
  Value<int> minus,
  Value<String?> imageUrl,
  Value<List<int>> anchors,
  Value<List<int>> reverseAnchors,
  Value<bool> isClipped,
  Value<DateTime?> clippedAt,
  Value<String?> clipMemo,
  Value<int> labelId,
  Value<int> rowid,
});

final class $$CommentsTableReferences
    extends BaseReferences<_$AppDatabase, $CommentsTable, Comment> {
  $$CommentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TopicsTable _topicIdTable(_$AppDatabase db) => db.topics
      .createAlias($_aliasNameGenerator(db.comments.topicId, db.topics.id));

  $$TopicsTableProcessedTableManager get topicId {
    final $_column = $_itemColumn<int>('topic_id')!;

    final manager = $$TopicsTableTableManager($_db, $_db.topics)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_topicIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$CommentsTableFilterComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get postedAt => $composableBuilder(
      column: $table.postedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get plus => $composableBuilder(
      column: $table.plus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minus => $composableBuilder(
      column: $table.minus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<int>, List<int>, String> get anchors =>
      $composableBuilder(
          column: $table.anchors,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<int>, List<int>, String>
      get reverseAnchors => $composableBuilder(
          column: $table.reverseAnchors,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get isClipped => $composableBuilder(
      column: $table.isClipped, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get clippedAt => $composableBuilder(
      column: $table.clippedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clipMemo => $composableBuilder(
      column: $table.clipMemo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get labelId => $composableBuilder(
      column: $table.labelId, builder: (column) => ColumnFilters(column));

  $$TopicsTableFilterComposer get topicId {
    final $$TopicsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.topicId,
        referencedTable: $db.topics,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TopicsTableFilterComposer(
              $db: $db,
              $table: $db.topics,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get number => $composableBuilder(
      column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get postedAt => $composableBuilder(
      column: $table.postedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get plus => $composableBuilder(
      column: $table.plus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minus => $composableBuilder(
      column: $table.minus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get anchors => $composableBuilder(
      column: $table.anchors, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get reverseAnchors => $composableBuilder(
      column: $table.reverseAnchors,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isClipped => $composableBuilder(
      column: $table.isClipped, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get clippedAt => $composableBuilder(
      column: $table.clippedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clipMemo => $composableBuilder(
      column: $table.clipMemo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get labelId => $composableBuilder(
      column: $table.labelId, builder: (column) => ColumnOrderings(column));

  $$TopicsTableOrderingComposer get topicId {
    final $$TopicsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.topicId,
        referencedTable: $db.topics,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TopicsTableOrderingComposer(
              $db: $db,
              $table: $db.topics,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CommentsTable> {
  $$CommentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get postedAt =>
      $composableBuilder(column: $table.postedAt, builder: (column) => column);

  GeneratedColumn<int> get plus =>
      $composableBuilder(column: $table.plus, builder: (column) => column);

  GeneratedColumn<int> get minus =>
      $composableBuilder(column: $table.minus, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get anchors =>
      $composableBuilder(column: $table.anchors, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<int>, String> get reverseAnchors =>
      $composableBuilder(
          column: $table.reverseAnchors, builder: (column) => column);

  GeneratedColumn<bool> get isClipped =>
      $composableBuilder(column: $table.isClipped, builder: (column) => column);

  GeneratedColumn<DateTime> get clippedAt =>
      $composableBuilder(column: $table.clippedAt, builder: (column) => column);

  GeneratedColumn<String> get clipMemo =>
      $composableBuilder(column: $table.clipMemo, builder: (column) => column);

  GeneratedColumn<int> get labelId =>
      $composableBuilder(column: $table.labelId, builder: (column) => column);

  $$TopicsTableAnnotationComposer get topicId {
    final $$TopicsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.topicId,
        referencedTable: $db.topics,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TopicsTableAnnotationComposer(
              $db: $db,
              $table: $db.topics,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$CommentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CommentsTable,
    Comment,
    $$CommentsTableFilterComposer,
    $$CommentsTableOrderingComposer,
    $$CommentsTableAnnotationComposer,
    $$CommentsTableCreateCompanionBuilder,
    $$CommentsTableUpdateCompanionBuilder,
    (Comment, $$CommentsTableReferences),
    Comment,
    PrefetchHooks Function({bool topicId})> {
  $$CommentsTableTableManager(_$AppDatabase db, $CommentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CommentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CommentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CommentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> topicId = const Value.absent(),
            Value<int> number = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String?> postedAt = const Value.absent(),
            Value<int> plus = const Value.absent(),
            Value<int> minus = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<List<int>> anchors = const Value.absent(),
            Value<List<int>> reverseAnchors = const Value.absent(),
            Value<bool> isClipped = const Value.absent(),
            Value<DateTime?> clippedAt = const Value.absent(),
            Value<String?> clipMemo = const Value.absent(),
            Value<int> labelId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CommentsCompanion(
            topicId: topicId,
            number: number,
            body: body,
            name: name,
            postedAt: postedAt,
            plus: plus,
            minus: minus,
            imageUrl: imageUrl,
            anchors: anchors,
            reverseAnchors: reverseAnchors,
            isClipped: isClipped,
            clippedAt: clippedAt,
            clipMemo: clipMemo,
            labelId: labelId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int topicId,
            required int number,
            required String body,
            Value<String?> name = const Value.absent(),
            Value<String?> postedAt = const Value.absent(),
            Value<int> plus = const Value.absent(),
            Value<int> minus = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<List<int>> anchors = const Value.absent(),
            Value<List<int>> reverseAnchors = const Value.absent(),
            Value<bool> isClipped = const Value.absent(),
            Value<DateTime?> clippedAt = const Value.absent(),
            Value<String?> clipMemo = const Value.absent(),
            Value<int> labelId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CommentsCompanion.insert(
            topicId: topicId,
            number: number,
            body: body,
            name: name,
            postedAt: postedAt,
            plus: plus,
            minus: minus,
            imageUrl: imageUrl,
            anchors: anchors,
            reverseAnchors: reverseAnchors,
            isClipped: isClipped,
            clippedAt: clippedAt,
            clipMemo: clipMemo,
            labelId: labelId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$CommentsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({topicId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (topicId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.topicId,
                    referencedTable:
                        $$CommentsTableReferences._topicIdTable(db),
                    referencedColumn:
                        $$CommentsTableReferences._topicIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$CommentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CommentsTable,
    Comment,
    $$CommentsTableFilterComposer,
    $$CommentsTableOrderingComposer,
    $$CommentsTableAnnotationComposer,
    $$CommentsTableCreateCompanionBuilder,
    $$CommentsTableUpdateCompanionBuilder,
    (Comment, $$CommentsTableReferences),
    Comment,
    PrefetchHooks Function({bool topicId})>;
typedef $$ClipLabelsTableCreateCompanionBuilder = ClipLabelsCompanion Function({
  Value<int> id,
  required String name,
  Value<DateTime> createdAt,
});
typedef $$ClipLabelsTableUpdateCompanionBuilder = ClipLabelsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> createdAt,
});

class $$ClipLabelsTableFilterComposer
    extends Composer<_$AppDatabase, $ClipLabelsTable> {
  $$ClipLabelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ClipLabelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClipLabelsTable> {
  $$ClipLabelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ClipLabelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClipLabelsTable> {
  $$ClipLabelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ClipLabelsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ClipLabelsTable,
    ClipLabel,
    $$ClipLabelsTableFilterComposer,
    $$ClipLabelsTableOrderingComposer,
    $$ClipLabelsTableAnnotationComposer,
    $$ClipLabelsTableCreateCompanionBuilder,
    $$ClipLabelsTableUpdateCompanionBuilder,
    (ClipLabel, BaseReferences<_$AppDatabase, $ClipLabelsTable, ClipLabel>),
    ClipLabel,
    PrefetchHooks Function()> {
  $$ClipLabelsTableTableManager(_$AppDatabase db, $ClipLabelsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClipLabelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClipLabelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClipLabelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ClipLabelsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              ClipLabelsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ClipLabelsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ClipLabelsTable,
    ClipLabel,
    $$ClipLabelsTableFilterComposer,
    $$ClipLabelsTableOrderingComposer,
    $$ClipLabelsTableAnnotationComposer,
    $$ClipLabelsTableCreateCompanionBuilder,
    $$ClipLabelsTableUpdateCompanionBuilder,
    (ClipLabel, BaseReferences<_$AppDatabase, $ClipLabelsTable, ClipLabel>),
    ClipLabel,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db, _db.topics);
  $$CommentsTableTableManager get comments =>
      $$CommentsTableTableManager(_db, _db.comments);
  $$ClipLabelsTableTableManager get clipLabels =>
      $$ClipLabelsTableTableManager(_db, _db.clipLabels);
}
