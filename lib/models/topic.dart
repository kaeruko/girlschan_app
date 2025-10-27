class Topic {
  final int? id;
  final String title;
  final String url;
  final int comments;
  final String posted_at;
  final String? thumb;

  Topic({
    this.id,
    required this.title,
    required this.url,
    required this.comments,
    required this.posted_at,
    this.thumb,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '(タイトルなし)',
      url: json['url'] as String? ?? '/topics/${json['id']}/',
      comments: json['comments'] as int? ?? 0,
      posted_at: json['posted_at'] as String? ?? '',
      thumb: json['thumb'] as String?,
    );
  }
}
