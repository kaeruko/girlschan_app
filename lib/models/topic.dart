class Topic {
  final String title;
  final String url;
  final int comments;
  final String time;

  Topic({
    required this.title,
    required this.url,
    required this.comments,
    required this.time,
  });

  factory Topic.fromCsv(List<String> row) {
    return Topic(
      title: row[0],
      url: row[1],
      comments: int.tryParse(row[2]) ?? 0,
      time: row[3],
    );
  }
}
