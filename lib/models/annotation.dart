enum AnnotationLabel {
  experience('experience', '体験談'),
  notExperience('not_experience', '体験談じゃない'),
  skipped('skipped', '保留');

  const AnnotationLabel(this.value, this.displayName);

  final String value;
  final String displayName;

  bool get isExportable =>
      this == AnnotationLabel.experience ||
      this == AnnotationLabel.notExperience;

  static AnnotationLabel parse(String value) {
    for (final label in values) {
      if (label.value == value) {
        return label;
      }
    }
    throw FormatException('未知のアノテーションラベルです: $value');
  }
}

class AnnotationTopicCandidate {
  const AnnotationTopicCandidate({
    required this.topicId,
    required this.title,
    required this.totalComments,
  });

  final int topicId;
  final String title;
  final int totalComments;
}

class AnnotationCommentSnapshot {
  const AnnotationCommentSnapshot({
    required this.topicId,
    required this.commentNo,
    required this.topicTitle,
    required this.body,
    required this.name,
    required this.postedAt,
    required this.plus,
    required this.minus,
    required this.anchors,
  });

  final int topicId;
  final int commentNo;
  final String topicTitle;
  final String body;
  final String? name;
  final String? postedAt;
  final int plus;
  final int minus;
  final List<int> anchors;
}

class AnnotationTopicProgress {
  const AnnotationTopicProgress({
    required this.topicId,
    required this.title,
    required this.total,
    required this.annotated,
    required this.isActive,
  });

  final int topicId;
  final String title;
  final int total;
  final int annotated;
  final bool isActive;
}

class AnnotationException implements Exception {
  const AnnotationException(this.message);

  final String message;

  @override
  String toString() => 'AnnotationException: $message';
}
