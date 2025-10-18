class Topic {
  final int? id;
  final String title;
  final String url;
  final int comments;
  final String time;
  final String? imageUrl;
  final String? thumb;

  Topic({
    this.id,
    required this.title,
    required this.url,
    required this.comments,
    required this.time,
    this.imageUrl,
    this.thumb,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int?,
      title: json['title'] as String? ?? '(タイトルなし)',
      url: json['url'] as String? ?? '/topics/${json['id']}/',
      comments: json['comments'] as int? ?? 0,
      time: json['time'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? json['thumb'] as String?,
      thumb: json['thumb'] as String?,
    );
  }

  factory Topic.fromCsv(List<String> row) {
    return Topic(
      title: row[0],
      url: row[1],
      comments: int.tryParse(row[2]) ?? 0,
      time: row[3],
      imageUrl: row.length > 4 ? row[4] : null,
    );
  }
}
